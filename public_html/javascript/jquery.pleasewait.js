(function($) {
  function getMaxZIndex(element) {
    var zIndexMax = 0;
    $('div').each(function () {
      var z = parseInt($(this).css('z-index'));
      if (z > zIndexMax) zIndexMax = z;
    });

    return zIndexMax;
  }

  function calculateZIndex(element){
    var z = 99999,
    element = $(element);

    // Increment from parent first
    if($.isNumeric(element.css('z-index'))){
      z = element.zIndex() + 10;
    } else {
      // TODO: Better way?
      var max = getMaxZIndex(element);
      if(max > 0){
        z = max + 10;
      }
    }

    return z;
  }

  function getOffset(element){
    var offset = element.offset(),
        position = element.css('position');

    if(position == "static"){
      offset.top = 0;
      offset.left = 0;
    }

    return offset;
  }

	function overlay(elements) {
			elements.each(function() {
				var element = $(this),
					offset = getOffset(element),
					html = '<div class="pleasewait" style="' +
						'display: block;'+
						'position: absolute;' +
						'background: #000;' +
						'opacity: 0.7;' +
						'text-align: center;' +
						'vertical-align: middle;' +
						'top:' + offset.top + 'px;' +
						'left:' + offset.left + 'px;' +
						'width:' + element.outerWidth() + 'px;' +
						'height:' + element.outerHeight() + 'px;' +
						'z-index:' + calculateZIndex(element) + ';">' +
            '<div class="pleasewait-content" style="text-align: center; color: #FFF; padding-top: ' + element.outerHeight() * 0.35 +'px; font-size: 1.2em;">' +
              '<img src=/jvsicons/pleasewait-loader.gif class="spinner" />' +
              '<p>Please wait...</p>' +
            '</div>' +
          '</div>';

        if(element.prev().hasClass("pleasewait")){
          resize(element);
        } else {
          element.before(html);
        }
			});
		
		return this;
	}

	function resize(elements) {
    elements.each(function() {
      var element = $(this),
          offset = element.offset();

      $(this).prev("div.pleasewait").css('top', offset.top + 'px');
      $(this).prev("div.pleasewait").css('left', offset.left + 'px');
      $(this).prev("div.pleasewait").css('width', element.outerWidth() + 'px');
      $(this).prev("div.pleasewait").css('height', element.outerHeight() + 'px');
      $(this).prev("div.pleasewait").css('z-index', calculateZIndex(this));

      $(this).prev("div.pleasewait").find(".pleasewait-content").css('padding-top', element.outerHeight() * 0.35 + 'px');
    });
		
		return this;
	}
	
	function close(elements) {
    elements.each(function() {
      $(this).prev("div.pleasewait").remove();
    });
		
		return this;
	}

  $.fn.pleasewait = function(method){
    switch(method){
      case "overlay":
        overlay(this);
      break;

      case "close":
        close(this);
      break;

     case "resize":
        resize(this);
      break;

      default:
        overlay(this);
      break;
    }
  };
})(jQuery);
