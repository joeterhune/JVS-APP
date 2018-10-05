(function($) {
  var DEBUG = true;

  function isWebKit(){
      return navigator.platform.indexOf("WebKit") != -1;
  }

	function shim(elements) {
		if (!isWebKit() || DEBUG) {
			elements.each(function() {
				var element = $(this),
					offset = element.offset(),
					html = '<iframe class="shim" frameborder="0" style="' +
						'display: block;'+
						'position: absolute;' +
						'top:' + offset.top + 'px;' +
						'left:' + offset.left + 'px;' +
						'width:' + element.outerWidth() + 'px;' +
						'height:' + element.outerHeight() + 'px;' +
						'z-index:' + Number.MAX_VALUE + ';' +
						'"/>';

        if(element.prev().hasClass("shim")){
          reshim(element);
        } else {
          element.before(html);
        }
			});
		}
		
		return this;
	}

	function reshim(elements) {
		if (!isWebKit() || DEBUG) {
			elements.each(function() {
				var element = $(this),
            offset = element.offset();

				$(this).prev("iframe.shim").css('top', offset.top + 'px');
				$(this).prev("iframe.shim").css('left', offset.left + 'px');
				$(this).prev("iframe.shim").css('width', element.outerWidth() + 'px');
				$(this).prev("iframe.shim").css('height', element.outerHeight() + 'px');
			});
		}
		
		return this;
	}
	
	function unshim(elements) {
		if (!isWebKit() || DEBUG) {
			elements.each(function() {
				$(this).prev("iframe.shim").remove();
			});
		}
		
		return this;
	}

  $.fn.shim = function(method){
    switch(method){
      case "shim":
        shim(this);
      break;

     case "unshim":
      case "close":
        unshim(this);
      break;

     case "reshim":
     case "resize":
        reshim(this);
      break;

      default:
        shim(this);
      break;
    }
  };
})(jQuery);
