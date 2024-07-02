document.addEventListener("DOMContentLoaded", function() {
    const timelineItems = document.querySelectorAll(".timeline-item");
    const overlay = document.getElementById("overlay");
    const overlayContentInner = document.getElementById("overlay-content-inner");
    const closeBtn = document.querySelector(".close-btn");

    timelineItems.forEach(item => {
        item.addEventListener("click", function() {
            const target = document.querySelector(this.getAttribute("data-target"));
            target.scrollIntoView({ behavior: 'smooth' });

            // Show overlay with project details
            const projectDetails = target.innerHTML;
            overlayContentInner.innerHTML = projectDetails;
            overlay.style.display = "flex";
        });
    });

    closeBtn.addEventListener("click", function() {
        overlay.style.display = "none";
    });

    // Close overlay when clicking outside the content
    overlay.addEventListener("click", function(event) {
        if (event.target === overlay) {
            overlay.style.display = "none";
        }
    });
});
