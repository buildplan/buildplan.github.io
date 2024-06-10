document.addEventListener('DOMContentLoaded', function () {
    const overlay = document.getElementById('overlay');
    const overlayTitle = document.getElementById('overlay-title');
    const overlayTag = document.getElementById('overlay-tag');
    const overlayDescription = document.getElementById('overlay-description');
    const overlayLink = document.getElementById('overlay-link');
    const closeOverlay = document.querySelector('.overlay .close');

    document.querySelectorAll('.grid').forEach(item => {
        item.addEventListener('click', function () {
            overlayTitle.textContent = this.dataset.title;
            overlayTag.textContent = this.dataset.tag;
            overlayDescription.textContent = this.dataset.description;
            overlayLink.href = this.dataset.link;
            overlay.style.display = 'block';
        });
    });

    closeOverlay.addEventListener('click', function () {
        overlay.style.display = 'none';
    });

    window.addEventListener('click', function (event) {
        if (event.target == overlay) {
            overlay.style.display = 'none';
        }
    });
});
