// Wait for the page's HTML to be fully loaded before running any scripts
document.addEventListener('DOMContentLoaded', () => {

    // --- 1. Activate Syntax Highlighting ---
    // This finds all <pre><code> blocks and tells Prism.js to highlight them.
    Prism.highlightAll();

    // --- 2. Copy Button Logic ---
    // Your robust copyCode function
    function copyCode(button) {
        var orig = button.textContent;
        var codeElem = button.nextElementSibling.querySelector('code');
        var text = codeElem.textContent || codeElem.innerText;

        navigator.clipboard.writeText(text).then(() => {
            button.textContent = '✅ Copied!';
            setTimeout(() => { button.textContent = orig; }, 1800);
        }, () => {
            button.textContent = '❌ Failed';
            setTimeout(() => { button.textContent = orig; }, 1800);
        });
    }

    // Find all buttons with the .copy-btn class
    const allCopyButtons = document.querySelectorAll('.copy-btn');

    // Add a click listener to each button
    allCopyButtons.forEach(button => {
        button.addEventListener('click', () => {
            // Call your copyCode function when the button is clicked
            copyCode(button);
        });
    });


    // --- 3. Review Button Hover Effect ---
    // Find the single "View Script Source" button by its new ID
    const reviewButton = document.getElementById('review-button');

    // Check if the button exists on the page
    if (reviewButton) {
        // Add a 'mouseover' listener to change the background color
        reviewButton.addEventListener('mouseover', () => {
            reviewButton.style.background = '#2ea043';
        });

        // Add a 'mouseout' listener to change the color back
        reviewButton.addEventListener('mouseout', () => {
            reviewButton.style.background = '#238636';
        });
    }

});
