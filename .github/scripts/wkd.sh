#!/usr/bin/env bash
set -euo pipefail

# OpenPGP Web Key Directory (WKD) Direct Method helper & validator for GitHub Pages.
# Compatible with macOS (Bash 3.2+, Homebrew GnuPG) and Ubuntu CI (GnuPG 2.4+).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${WKD_REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
WKD_DIR="$REPO_ROOT/.well-known/openpgpkey"
POLICY_FILE="$WKD_DIR/policy"
HU_DIR="$WKD_DIR/hu"
CONFIG_FILE="$REPO_ROOT/_config.yml"
CNAME_FILE="$REPO_ROOT/CNAME"

TMP_DIRS=()

cleanup() {
  local d
  for d in "${TMP_DIRS[@]+"${TMP_DIRS[@]}"}"; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

make_temp_dir() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/wkd-tool.XXXXXX")"
  chmod 700 "$d"
  TMP_DIRS+=("$d")
  printf '%s\n' "$d"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

get_domain() {
  if [ -n "${WKD_DOMAIN:-}" ]; then
    to_lower "$WKD_DOMAIN"
    return
  fi
  if [ -f "$CNAME_FILE" ]; then
    local d
    d="$(tr -d ' \t\r\n' < "$CNAME_FILE")"
    if [ -n "$d" ]; then
      to_lower "$d"
      return
    fi
  fi
  die "Could not determine domain: $CNAME_FILE is missing or empty (or set WKD_DOMAIN)."
}

find_wks_client() {
  local candidate
  if command -v gpg-wks-client >/dev/null 2>&1; then
    command -v gpg-wks-client
    return 0
  fi
  for candidate in /usr/lib/gnupg/gpg-wks-client /usr/libexec/gpg-wks-client; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

wkd_hash() {
  local email="$1"
  local local_part
  local wks_bin=""

  if [[ "$email" != *@* ]]; then
    die "Invalid email address: $email"
  fi

  if wks_bin="$(find_wks_client)"; then
    "$wks_bin" --print-wkd-hash "$email" | awk 'NR==1 {print $1}'
    return 0
  fi

  local_part="$(to_lower "${email%@*}")"
  python3 - "$local_part" <<'PY'
import hashlib
import sys

alphabet = "ybndrfg8ejkmcpqxot1uwisza345h769"
digest = hashlib.sha1(sys.argv[1].encode("utf-8")).digest()
value = int.from_bytes(digest, "big")
print("".join(alphabet[(value >> (i * 5)) & 0x1F] for i in range(31, -1, -1)))
PY
}

extract_email_from_uid() {
  local uid="$1"
  local unescaped
  # Unescape GnuPG --with-colons \xNN hex escapes if present
  unescaped="$(printf '%b' "$uid")"
  if [[ "$unescaped" =~ \<([^[:space:]\<\>]+@[^[:space:]\<\>]+)\> ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$unescaped" =~ ^([^[:space:]\<\>]+@[^[:space:]\<\>]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

check_jekyll_include() {
  [ -f "$CONFIG_FILE" ] || die "Missing $CONFIG_FILE"

  # Verify .well-known appears in the top-level YAML `include:` list
  if ! awk '
    /^[[:space:]]*#/ { next }
    /^include:[[:space:]]*\[/ {
      if ($0 ~ /[\x27"]?\.well-known[\x27"]?/) { found = 1 }
      in_include = 0
      next
    }
    /^include:[[:space:]]*$/ {
      in_include = 1
      next
    }
    in_include {
      if (/^[[:space:]]*-[[:space:]]*[\x27"]?\.well-known[\x27"]?[[:space:]]*(#.*)?$/) {
        found = 1
      } else if (/^[^[:space:]#]/) {
        in_include = 0
      }
    }
    END { exit(found ? 0 : 1) }
  ' "$CONFIG_FILE"; then
    return 1
  fi
  return 0
}

check_policy_file() {
  if [ ! -e "$POLICY_FILE" ]; then
    printf 'ERROR: Missing policy file: %s\n' "$POLICY_FILE" >&2
    return 1
  fi
  if [ -L "$POLICY_FILE" ] || [ ! -f "$POLICY_FILE" ]; then
    printf 'ERROR: Policy path must be a regular file (not symlink): %s\n' "$POLICY_FILE" >&2
    return 1
  fi
  # Empty file is the standard valid policy for static WKD
  if [ ! -s "$POLICY_FILE" ]; then
    return 0
  fi

  local line_no=0 line trimmed
  while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))
    trimmed="$(printf '%s' "$line" | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -z "$trimmed" ] || [[ "$trimmed" == \#* ]]; then
      continue
    fi
    case "$trimmed" in
      mailbox-only|dane-only|auth-submit|protocol-version:*|submission-address:*|draft-version:*)
        ;;
      *)
        printf 'ERROR: Invalid WKD policy directive at %s:%d: %s\n' "$POLICY_FILE" "$line_no" "$trimmed" >&2
        return 1
        ;;
    esac
  done < "$POLICY_FILE"
  return 0
}

cmd_validate() {
  command -v gpg >/dev/null 2>&1 || die "gpg is required"

  local domain errors=0 key_count=0
  domain="$(get_domain)"

  if ! check_jekyll_include; then
    printf 'ERROR: %s does not include ".well-known" under top-level include:\n' "$CONFIG_FILE" >&2
    errors=$((errors + 1))
  fi

  if ! check_policy_file; then
    errors=$((errors + 1))
  fi

  if [ -L "$HU_DIR" ] || [ ! -d "$HU_DIR" ]; then
    printf 'ERROR: Missing or invalid directory: %s\n' "$HU_DIR" >&2
    exit 1
  fi

  local tmp_gnupg
  tmp_gnupg="$(make_temp_dir)"

  local entry base packets colons line rec_type status fpr uid_str email email_domain expected_hash
  local uid_count has_pub file_errors key_status summary_emails

  # Iterate over all entries including dotfiles (catches stray .DS_Store, etc.)
  while IFS= read -r -d '' entry; do
    base="$(basename "$entry")"
    file_errors=0

    if [ -L "$entry" ] || [ ! -f "$entry" ]; then
      printf 'ERROR: hu/%s is not a regular file\n' "$base" >&2
      errors=$((errors + 1))
      continue
    fi

    if [[ ! "$base" =~ ^[ybndrfg8ejkmcpqxot1uwisza345h769]{32}$ ]]; then
      printf 'ERROR: hu/%s is not a valid 32-char z-base-32 WKD hash filename\n' "$base" >&2
      errors=$((errors + 1))
      continue
    fi

    if [ ! -s "$entry" ]; then
      printf 'ERROR: hu/%s is empty\n' "$base" >&2
      errors=$((errors + 1))
      continue
    fi

    if head -c 64 "$entry" | LC_ALL=C grep -q -- "-----BEGIN PGP"; then
      printf 'ERROR: hu/%s is ASCII-armored (WKD requires raw binary OpenPGP packets)\n' "$base" >&2
      errors=$((errors + 1))
      continue
    fi

    if ! packets="$(gpg --homedir "$tmp_gnupg" --batch --no-tty --no-options --quiet --list-packets "$entry" 2>&1)"; then
      printf 'ERROR: hu/%s failed OpenPGP packet parsing:\n%s\n' "$base" "$packets" >&2
      errors=$((errors + 1))
      continue
    fi

    if printf '%s\n' "$packets" | grep -q ":secret.*key packet:"; then
      printf 'ERROR: hu/%s contains SECRET KEY material! Remove immediately.\n' "$base" >&2
      errors=$((errors + 1))
      continue
    fi

    if ! printf '%s\n' "$packets" | grep -q ":public key packet:"; then
      printf 'ERROR: hu/%s does not contain a public key packet\n' "$base" >&2
      errors=$((errors + 1))
      continue
    fi

    if ! colons="$(gpg --homedir "$tmp_gnupg" --batch --no-tty --no-options --quiet --show-keys --with-colons --with-fingerprint "$entry" 2>&1)"; then
      printf 'ERROR: hu/%s failed gpg --show-keys:\n%s\n' "$base" "$colons" >&2
      errors=$((errors + 1))
      continue
    fi

    has_pub=0
    uid_count=0
    fpr=""
    key_status="ok"
    summary_emails=""

    while IFS= read -r line; do
      rec_type="${line%%:*}"
      case "$rec_type" in
        pub)
          has_pub=1
          status="$(printf '%s' "$line" | cut -d: -f2)"
          case "$status" in
            r)
              warn "hu/$base primary key is revoked"
              key_status="revoked"
              ;;
            e)
              warn "hu/$base primary key is expired"
              key_status="expired"
              ;;
          esac
          ;;
        sec|ssb)
          printf 'ERROR: hu/%s contains secret key record (%s)\n' "$base" "$rec_type" >&2
          file_errors=$((file_errors + 1))
          ;;
        fpr)
          if [ -z "$fpr" ]; then
            fpr="$(printf '%s' "$line" | cut -d: -f10)"
          fi
          ;;
        uid)
          uid_count=$((uid_count + 1))
          uid_str="$(printf '%s' "$line" | cut -d: -f10)"
          if ! email="$(extract_email_from_uid "$uid_str")"; then
            printf 'ERROR: hu/%s UID has no parseable email address: %s\n' "$base" "$uid_str" >&2
            file_errors=$((file_errors + 1))
            continue
          fi
          email_domain="$(to_lower "${email#*@}")"
          if [ "$email_domain" != "$domain" ]; then
            printf 'ERROR: hu/%s contains UID for wrong domain "%s" (expected "%s"): %s\n' "$base" "$email_domain" "$domain" "$email" >&2
            file_errors=$((file_errors + 1))
            continue
          fi
          expected_hash="$(wkd_hash "$email")"
          if [ "$expected_hash" != "$base" ]; then
            printf 'ERROR: hu/%s UID "%s" hashes to "%s" (filename mismatch or bundled unrelated UID)\n' "$base" "$email" "$expected_hash" >&2
            file_errors=$((file_errors + 1))
            continue
          fi
          if [ -z "$summary_emails" ]; then
            summary_emails="$email"
          else
            summary_emails="$summary_emails, $email"
          fi
          ;;
      esac
    done <<< "$colons"

    if [ "$has_pub" -eq 0 ]; then
      printf 'ERROR: hu/%s has no public key record\n' "$base" >&2
      file_errors=$((file_errors + 1))
    fi
    if [ "$uid_count" -eq 0 ]; then
      printf 'ERROR: hu/%s has no UID records\n' "$base" >&2
      file_errors=$((file_errors + 1))
    fi

    if [ "$file_errors" -gt 0 ]; then
      errors=$((errors + file_errors))
    else
      key_count=$((key_count + 1))
      printf 'OK  %s  %-28s  %s  [%s]\n' "$base" "$summary_emails" "${fpr:-unknown}" "$key_status"
    fi
  done < <(find "$HU_DIR" -mindepth 1 -maxdepth 1 -print0 | LC_ALL=C sort -z)

  if [ "$key_count" -eq 0 ] && [ "$errors" -eq 0 ]; then
    printf 'ERROR: No key files found in %s\n' "$HU_DIR" >&2
    errors=$((errors + 1))
  fi

  if [ "$errors" -gt 0 ]; then
    printf '\nValidation failed with %d error(s).\n' "$errors" >&2
    exit 1
  fi

  printf '\nValidation passed: %d WKD key(s) ready for %s.\n' "$key_count" "$domain"
}

cmd_list() {
  command -v gpg >/dev/null 2>&1 || die "gpg is required"
  [ -d "$HU_DIR" ] || die "Directory not found: $HU_DIR"

  local tmp_gnupg entry base found=0
  tmp_gnupg="$(make_temp_dir)"

  while IFS= read -r -d '' entry; do
    base="$(basename "$entry")"
    found=1
    printf '=== hu/%s (%s bytes) ===\n' "$base" "$(wc -c < "$entry" | tr -d ' ')"
    gpg --homedir "$tmp_gnupg" --batch --no-tty --no-options --quiet --show-keys --with-wkd-hash --with-fingerprint "$entry"
  done < <(find "$HU_DIR" -mindepth 1 -maxdepth 1 -type f -print0 | LC_ALL=C sort -z)

  if [ "$found" -eq 0 ]; then
    printf 'No WKD key files in %s\n' "$HU_DIR"
  fi
}

cmd_import() {
  [ $# -eq 1 ] || die "Usage: $0 import <source_dir>"
  local src="$1"
  local resolved=""

  if [ -d "$src/.well-known/openpgpkey/hu" ]; then
    resolved="$src/.well-known/openpgpkey"
  elif [ -d "$src/openpgpkey/hu" ]; then
    resolved="$src/openpgpkey"
  elif [ -d "$src/hu" ]; then
    resolved="$src"
  else
    die "Could not find openpgpkey/hu directory under: $src"
  fi

  mkdir -p "$HU_DIR"

  if [ -f "$resolved/policy" ]; then
    cp "$resolved/policy" "$POLICY_FILE"
  elif [ ! -f "$POLICY_FILE" ]; then
    : > "$POLICY_FILE"
  fi

  local entry base copied=0
  while IFS= read -r -d '' entry; do
    base="$(basename "$entry")"
    if [ "$base" = ".DS_Store" ]; then
      continue
    fi
    cp "$entry" "$HU_DIR/$base"
    copied=$((copied + 1))
  done < <(find "$resolved/hu" -mindepth 1 -maxdepth 1 -type f -print0)

  if [ "$copied" -eq 0 ]; then
    die "No key files found in $resolved/hu"
  fi

  printf 'Imported %d key file(s) from %s into %s\n\n' "$copied" "$resolved" "$WKD_DIR"
  cmd_validate
}

cmd_add() {
  [ $# -eq 2 ] || die "Usage: $0 add <fingerprint-or-keyfile> <email>"
  command -v gpg >/dev/null 2>&1 || die "gpg is required"

  local key_ref="$1"
  local email="$2"
  local domain email_lower email_domain hash tmp_out tmp_gnupg

  domain="$(get_domain)"
  email_lower="$(to_lower "$email")"

  if [[ "$email_lower" != *@* ]]; then
    die "Invalid email address: $email"
  fi
  email_domain="${email_lower#*@}"
  if [ "$email_domain" != "$domain" ]; then
    die "Email domain '$email_domain' does not match site domain '$domain'"
  fi

  hash="$(wkd_hash "$email_lower")"
  tmp_gnupg="$(make_temp_dir)"
  tmp_out="$tmp_gnupg/$hash"

  if [ -f "$key_ref" ]; then
    # Use import-export in an isolated homedir (--no-options guarantees unarmored binary
    # output while auto-detecting both .asc armored and binary inputs without gpg-agent).
    gpg --homedir "$tmp_gnupg" --batch --no-tty --no-options --quiet \
      --import-options import-export,import-clean,import-minimal \
      --import-filter "keep-uid=mbox == $email_lower" \
      --import "$key_ref" > "$tmp_out"
  else
    gpg --batch --no-tty \
      --no-armor \
      --export-options export-clean,export-minimal \
      --export-filter "keep-uid=mbox == $email_lower" \
      --export "$key_ref" > "$tmp_out"
  fi

  if [ ! -s "$tmp_out" ]; then
    die "Export produced an empty file. Check that key '$key_ref' has UID '$email_lower'."
  fi

  if gpg --homedir "$tmp_gnupg" --batch --no-tty --no-options --quiet --list-packets "$tmp_out" 2>/dev/null | grep -q ":secret.*key packet:"; then
    die "Refusing to write secret key material into repository!"
  fi

  mkdir -p "$HU_DIR"
  if [ ! -f "$POLICY_FILE" ]; then
    : > "$POLICY_FILE"
  fi
  cp "$tmp_out" "$HU_DIR/$hash"

  printf 'Wrote %s -> %s\n\n' "$email_lower" ".well-known/openpgpkey/hu/$hash"
  cmd_validate
}

cmd_remove() {
  [ $# -eq 1 ] || die "Usage: $0 remove <email>"
  local email="$1"
  local hash target

  hash="$(wkd_hash "$email")"
  target="$HU_DIR/$hash"

  if [ ! -f "$target" ]; then
    die "No key file found for $email (expected .well-known/openpgpkey/hu/$hash)"
  fi

  rm -f "$target"
  printf 'Removed %s (.well-known/openpgpkey/hu/%s)\n' "$email" "$hash"
}

cmd_check_live() {
  [ $# -eq 1 ] || die "Usage: $0 check-live <email>"
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v gpg >/dev/null 2>&1 || die "gpg is required"

  local email="$1"
  local domain email_lower email_domain local_part hash
  domain="$(get_domain)"
  email_lower="$(to_lower "$email")"
  email_domain="${email_lower#*@}"
  local_part="${email_lower%@*}"

  if [ "$email_domain" != "$domain" ]; then
    die "Email domain '$email_domain' does not match site domain '$domain'"
  fi

  hash="$(wkd_hash "$email_lower")"

  if command -v dig >/dev/null 2>&1; then
    printf '=== DNS check (openpgpkey.%s should have no A/AAAA for Direct Method) ===\n' "$domain"
    local a_rec aaaa_rec txt_rec
    a_rec="$(dig +short A "openpgpkey.$domain" || true)"
    aaaa_rec="$(dig +short AAAA "openpgpkey.$domain" || true)"
    txt_rec="$(dig +short TXT "openpgpkey.$domain" || true)"
    printf 'A:    %s\n' "${a_rec:-<none>}"
    printf 'AAAA: %s\n' "${aaaa_rec:-<none>}"
    printf 'TXT:  %s\n\n' "${txt_rec:-<none>}"
    if [ -n "$a_rec" ] || [ -n "$aaaa_rec" ]; then
      warn "openpgpkey.$domain resolves to an IP; WKD clients will try Advanced Method instead of Direct Method!"
    fi
  fi

  local policy_url="https://$domain/.well-known/openpgpkey/policy"
  local key_url="https://$domain/.well-known/openpgpkey/hu/$hash?l=$local_part"

  printf '=== HTTP policy check: %s ===\n' "$policy_url"
  curl -fsSI "$policy_url" | grep -iE '^(HTTP/|content-type:|access-control-allow-origin:|content-length:)' || true
  printf '\n'

  printf '=== HTTP key check: %s ===\n' "$key_url"
  curl -fsSI "$key_url" | grep -iE '^(HTTP/|content-type:|access-control-allow-origin:|content-length:)' || true
  printf '\n'

  local tmp_gnupg wks_bin=""
  tmp_gnupg="$(make_temp_dir)"

  printf '=== GnuPG WKD locate test: %s ===\n' "$email_lower"
  gpg --homedir "$tmp_gnupg" --batch --no-tty \
    --auto-key-locate clear,nodefault,wkd \
    --locate-external-keys "$email_lower"

  if wks_bin="$(find_wks_client)"; then
    printf '\n=== gpg-wks-client check ===\n'
    "$wks_bin" -v --check "$email_lower"
  fi
}

usage() {
  cat <<EOF
Usage: $0 <command> [args]

Commands:
  validate                             Validate _config.yml, policy, and all keys in .well-known/openpgpkey/hu/
  list                                 Show details of all WKD keys in the repository
  import <source_dir>                  Import policy and hu/* from a pre-generated WKD directory and validate
  add <fingerprint-or-keyfile> <email> Export clean binary public key for <email> into hu/<hash> and validate
  remove <email>                       Remove the WKD key file for <email>
  check-live <email>                   Verify live HTTPS headers, DNS fallback, and gpg WKD lookup after deploy
EOF
}

main() {
  if [ $# -lt 1 ]; then
    usage >&2
    exit 1
  fi

  local cmd="$1"
  shift
  case "$cmd" in
    validate)    cmd_validate "$@" ;;
    list)        cmd_list "$@" ;;
    import)      cmd_import "$@" ;;
    add)         cmd_add "$@" ;;
    remove)      cmd_remove "$@" ;;
    check-live)  cmd_check_live "$@" ;;
    -h|--help|help) usage ;;
    *)
      printf 'ERROR: Unknown command: %s\n\n' "$cmd" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
