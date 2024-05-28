/*
	Spectral by HTML5 UP
	html5up.net | @ajlkn
	Free for personal and commercial use under the CCA 3.0 license (html5up.net/license)
*/

(function($) {

	var	$window = $(window),
		$body = $('body'),
		$wrapper = $('#page-wrapper'),
		$banner = $('#banner'),
		$header = $('#header');

	// Breakpoints.
		breakpoints({
			xlarge:   [ '1281px',  '1680px' ],
			large:    [ '981px',   '1280px' ],
			medium:   [ '737px',   '980px'  ],
			small:    [ '481px',   '736px'  ],
			xsmall:   [ null,      '480px'  ]
		});

	// Play initial animations on page load.
		$window.on('load', function() {
			window.setTimeout(function() {
				$body.removeClass('is-preload');
			}, 100);
		});

	// Mobile?
		if (browser.mobile)
			$body.addClass('is-mobile');
		else {

			breakpoints.on('>medium', function() {
				$body.removeClass('is-mobile');
			});

			breakpoints.on('<=medium', function() {
				$body.addClass('is-mobile');
			});

		}

	// Scrolly.
		$('.scrolly')
			.scrolly({
				speed: 1500,
				offset: $header.outerHeight()
			});

	// Menu.
	
	// Existing menu panel code 
		$(document).ready(function() {
  		$('#menu')
    			.append('<a href="#menu" class="close"></a>')
    			.appendTo($body)
    			.panel({
      			delay: 500,
      			hideOnClick: true,
      			hideOnSwipe: true,
      			resetScroll: true,
      			resetForms: true,
      			side: 'right',
      			target: $body,
      			visibleClass: 'is-menu-visible'
    				});
					});

	// New code for sticky menu behavior

		// function handleScroll() {
  			// const nav = document.getElementById('nav');
  			// const scrollY = window.scrollY; // Get scroll position
  			// const sectionOne = document.getElementById('one'); // Get target section
  			// const sectionTop = sectionOne.offsetTop; // Get section's offset from top

  			// if (scrollY > sectionTop) {
    				// nav.classList.add('sticky'); // Add 'sticky' class when scrolled past section
  				// } else {
    				// nav.classList.remove('sticky'); // Remove 'sticky' class on top or before section
  					// }
				// }

	// Add event listener for scroll
		// window.addEventListener('scroll', handleScroll);

	// Optional: Call the function on page load
		// handleScroll();


	// Header.
		if ($banner.length > 0
		&&	$header.hasClass('alt')) {

			$window.on('resize', function() { $window.trigger('scroll'); });

			$banner.scrollex({
				bottom:		$header.outerHeight() + 1,
				terminate:	function() { $header.removeClass('alt'); },
				enter:		function() { $header.addClass('alt'); },
				leave:		function() { $header.removeClass('alt'); }
			});

		}

})(jQuery);

const currentYear = new Date().getFullYear();
document.getElementById('current-year').textContent = currentYear;

