document.addEventListener('DOMContentLoaded', function () {
    const overlay = document.getElementById('overlay');
    const overlayTitle = document.getElementById('overlay-title');
    const overlayTag = document.getElementById('overlay-tag');
    const overlayDescription = document.getElementById('overlay-description');
    const overlayLink = document.getElementById('overlay-link');
    const overlayImages = document.getElementById('overlay-images');
    const closeOverlay = document.querySelector('.overlay .close');

    function decodeHtml(html) {
        const txt = document.createElement('textarea');
        txt.innerHTML = html;
        return txt.value;
    }

    document.querySelectorAll('.grid').forEach(item => {
        item.addEventListener('click', function () {
            overlayTitle.textContent = this.dataset.title;
            overlayTag.textContent = this.dataset.tag;
            overlayDescription.innerHTML = decodeHtml(this.dataset.description);
            overlayLink.href = this.dataset.link;

            // Clear previous images
            overlayImages.innerHTML = '';

            // Add new images
            const images = this.dataset.images.split(',');
            images.forEach(src => {
                const img = document.createElement('img');
                img.src = src;
                overlayImages.appendChild(img);
            });

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
