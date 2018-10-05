/*jslint indent: 2, plusplus: true, sloppy: true, todo: true, white: true, unparam: true */
/*global $:false, window: false */
var DocViewer = {};

// Window
DocViewer.Window = function (el, files, options) {
    var visiblePanes = $.cookie().visiblePanes;
    this.options = $.extend({}, this.defaultOptions, options || {});
    this.documents = {};
    this.panes = [];
    this.element = $(el);
    this.element.data('dv-window', this);
    
    // override with cookie for visiblePanes
    if($.isNumeric(visiblePanes)){
        this.options.visiblePanes = parseInt(visiblePanes);
    }
    
    this.initialize(files);
};

DocViewer.Window.prototype = {
    initialize: function(files){
        files = files || [];
        
        var w = this;
        
        var toolbarEl = $("<div class='dv-toolbar'>" +
                      "<div class='dv-document-list-toggle'>" +
                      "<i class='fa fa-list-alt' title=''></i>" +
                      "</div>" +
                      "<div class='dv-window-name dv-name'>" + this.name() + "</div>" +
                      "<div class='dv-controls'>" +
                      "<i class='fa fa-floppy-o dv-save' title='Save This Docket Configuration'></i>" +
                      "<div class='dv-pane-controls'>" +
                      "<i class='fa fa-columns dv-toggle-panes' title='Toggle 1/2/3 Document View'></i><a href='#' class='dv-one-pane'>&nbsp;1&nbsp;</a>|<a href='#' class='dv-two-pane active'>&nbsp;2&nbsp;</a>|<a href='#' class='dv-three-pane'>&nbsp;3&nbsp;</a>" +
                      "</div>" +
                      "<i class='fa fa-chevron-circle-left dv-scroll-left' title='Scroll left one document'></i>" +
                      "<i class='fa fa-chevron-circle-right dv-scroll-right' title='Scroll right one document'></i>" +
                      "</div>" +
                      "</div>" +
                      "</div>" +
                      "<div class='dv-container'>" +
                      "<div class='dv-document-list'>" +
                      "<ul></ul>" +
                      "</div>" +
                      "<div class='dv-panes'>" +
                      "</div>" +
                      "</div>"
        );
        
        this.element.addClass("dv-window");
        this.element.height(this.element.parents().first().height());
        this.element.width(this.options.width);
        
        this.element.append(toolbarEl);
        this.setVisiblePanes(this.options.visiblePanes);
         
        // Open any initial documents
        //$.each(files, function(i, doc){
        //    w.addPane(i, doc, w.options.pane);
        //});
        
        // Listen for toolbar events
        this.addListeners();
    },
    
    addListeners: function(){
        var w = this;
        
        // Move Left
        this.element.on('click', '.dv-move-left', function(){
            var el = $(this).closest('.dv-pane');
            var pane = el.data('dv-pane');
            
            if(pane.index > 0){
                w.panes.splice(pane.index, 1);
                pane.index--;
                w.panes.splice(pane.index, 0, pane);
                
                w.redraw(pane.index - 1);
                
                // Fix glitch when this was the last document
                if(pane.index + 1 !== w.firstVisiblePane()){
                    w.scrollToPane(pane.index+1);
                } else {
                    w.scrollToPane(pane.index);
                }
            }
        });
        
        // Move Right
        this.element.on('click', '.dv-move-right', function(){
            var el = $(this).closest('.dv-pane');
            var pane = el.data('dv-pane');
            
            if(pane.index < w.panes.length - 1){
                w.panes.splice(pane.index, 1);
                pane.index++;
                w.panes.splice(pane.index, 0, pane);
                
                w.redraw(pane.index - 1);

                w.scrollToPane(pane.index);
            }
        });
        
        // Fullscreen
        this.element.on('click', '.dv-fullscreen', function(){
            var el = $(this).closest('.dv-pane');
            var pane = el.data('dv-pane');
            
            el.siblings().each(function(i, el){
                $(el).data('dv-pane').hide();
            });
            pane.fullscreen();
        });
        
        // Minimize
        this.element.on('click', '.dv-minimize', function(){
            var el = $(this).closest('.dv-pane');
            var pane = el.data('dv-pane');
            
            pane.minimize();
            el.siblings().each(function(i, el){
                $(el).data('dv-pane').show();
            });
            
            // Force redraw (should fix any left over artifact issues from incorrect sizes)
            w.redraw();
        });
        
        // Close
        this.element.on('click', '.dv-close', function(){
            var el = $(this).closest('.dv-pane');
            var pane = el.data('dv-pane');
            
            w.removePane(pane.index);
        });
        
        // Single
        this.element.on('click', '.dv-single', function(){
            var el = $(this).closest('.dv-pane');
            var pane = el.data('dv-pane');
            
            w.groupDocumentPanes(pane.doc, pane.index);
            
            // Remove extras
            w.trimAdjacentPanes(pane.index, 1);
            w.updateDocumentPaneCount(pane.doc);
            w.scrollToPane(pane.index);
        });
        
        // Duplicate
        this.element.on('click', '.dv-duplicate', function(){
            var el = $(this).closest('.dv-pane');
            var adjacentPanes = [];
            var pane = el.data('dv-pane');
            
            w.groupDocumentPanes(pane.doc, pane.index);
            adjacentPanes = w.adjacentPanes(pane.index);
            
            if(adjacentPanes.length < 2){
                w.addPane(pane.index + 1, pane.doc, pane.options, true);
                adjacentPanes.push(w.panes[pane.index + 1]);
            }
            
            // Remove extras
            w.trimAdjacentPanes(pane.index, 2);
            w.updateDocumentPaneCount(pane.doc);
            w.scrollToPane(adjacentPanes[0].index, true);
        });
        
        this.element.on('click', '.dv-triplicate', function(){
            var el = $(this).closest('.dv-pane');
            var i=1;
            var adjacentPanes = [];
            var pane = el.data('dv-pane');
            
            w.groupDocumentPanes(pane.doc, pane.index);
            adjacentPanes = w.adjacentPanes(pane.index);
            
            if(adjacentPanes.length < 3 || !w.isPaneVisible(adjacentPanes[0].index)){
                for(i = 1; adjacentPanes.length < 3; i++){
                    w.addPane(pane.index + i, pane.doc, pane.options, true);
                    adjacentPanes.push(w.panes[pane.index + i]);
                }
            }
            
            // Remove extras
            w.trimAdjacentPanes(pane.index, 3);
            w.updateDocumentPaneCount(pane.doc);
            w.scrollToPane(adjacentPanes[0].index, true);
        });
        
        // Popout
        this.element.on('click', '.dv-popout', function(){
            var el = $(this).closest('.dv-pane');
            var pane = el.data('dv-pane');
            var width = pane.options.popoutWidth || w.docWidth();
            var height = pane.options.popoutHeight || w.docHeight();
            var left=screen.width-width-10;
            
            if(w.options.popupFunction){
                w.options.popupFunction(pane);
            } else {
                popout = window.open(pane.getOpenUrl(), pane.name(), "resizable=yes,toolbar=0,titlebar=0,location=0,menubar=0,toolbar=0,width=" + width + ",height=" + height + ",top=0,left=" + left);
                popout.focus();
            }
        });
        
        // Save
        this.element.on('click', '.dv-save', function(){
            if(w.options.saveFunction){
                w.options.saveFunction(w);
            }
        });
        
        // Scroll Left
        this.element.on('click', '.dv-scroll-left', function(){
            w.scrollLeft();
        });
        
        // Scroll Right
        this.element.on('click', '.dv-scroll-right', function(){
            w.scrollRight();
        });
        
        // 1/2/3 Document Toggle
        this.element.on('click', '.dv-toggle-panes', function(){
            var panes = w.options.visiblePanes + 1;
            panes = panes > 3 ? 1 : panes;
            
            w.setVisiblePanes(panes);
        });
        
        this.element.on('click', '.dv-one-pane', function(e){
            e.stopImmediatePropagation();
            w.setVisiblePanes(1);
        });
        
        this.element.on('click', '.dv-two-pane', function(e){
            e.stopImmediatePropagation();
            w.setVisiblePanes(2);
        });
        
        this.element.on('click', '.dv-three-pane', function(e){
            e.stopImmediatePropagation();
            w.setVisiblePanes(3);
        });
        
        // Document List Toggle
        this.element.on('click', '.dv-document-list-toggle', function(e){
            var p = w.firstVisiblePane();
            w.element.find(".dv-document-list").toggle();
            w.redraw();
            w.scrollToPane(p, true);
        });
        
        this.element.on('click', '.dv-document-list ul li', function(e){
            var paneId = $(this).attr('data-pane-id');
            w.scrollToPane(paneId, true);
            $(w.panes[paneId].element).css({opacity: 0.2}).animate({opacity: 1}, 1000);
        });
        
        this.element.find('.dv-panes').on('scroll', '', function(){
            w.redrawScrollControls();
        });
        
        // Note / Workflow
        this.element.on('click', '.dv-note', function(){
            var el = $(this).closest('.dv-pane');
            var pane = el.data('dv-pane');
            
            if(w.options.noteFunction){
                w.options.noteFunction(pane);
            }
        });
        
        this.element.on('click', '.dv-workflow', function(el){
            var ele = $(this).closest('.dv-pane');
            var pane = ele.data('dv-pane');
            
            if(w.options.workflowFunction){
                w.options.workflowFunction(pane);
            }
        });
    },
    
    firstVisiblePane: function(){
        var el = this.element.find(".dv-panes");
        
        return Math.floor(el.scrollLeft() / this.docWidth());
    },
    
    isPaneVisible: function(index){
        var el = this.element.find(".dv-panes");
        var left = this.panes[index].left;
        var right = left + this.docWidth();
        
        // Ensure full document is visible
        return (left >= el.scrollLeft() && right <= el.scrollLeft() + el.width());
    },
    
    adjacentPanes: function(index){
        var panes = [];
        var pane = this.panes[index];
        var i = index;
        var p;
        
        // Before
        while(i >= 0){
            p = this.panes[i];
            if(p.doc !== pane.doc){
                break;
            }
            
            panes.unshift(p);
            i--;
        }
        
        // After
        i = index + 1;
        while(i < this.panes.length){
            p = this.panes[i];
            if(p.doc !== pane.doc){
                break;
            }
            
            panes.push(p);
            i++;
        }
        return panes;
    },
    
    trimAdjacentPanes: function(index, limit){
        var adjacent = this.adjacentPanes(index);
        var n = adjacent.length - limit;
        var w = this;
        
        if(adjacent.length > limit){
            // TODO: This favors the first document in the adjacent list, should it favor visible documents?
            $.each(this.panes.splice(adjacent[0].index + 1, n), function(i, p){
                p.close();
                
                w.documents[p.doc]--;
                w.updateDocumentPaneCount(p.doc);
            });
            
            this.redraw(adjacent[0].index);
        }
    },
    
    scrollLeft: function(){
        var pos = this.firstVisiblePane() - 1;
        pos = pos < 0 ? 0 : pos;
        
        this.scrollToPane(pos, true);
    },
    
    scrollRight: function(){
    var n = Math.ceil(this.panes.length / this.options.visiblePanes),
    pos = this.firstVisiblePane() + 1;

    pos = pos > n ? n : pos;

    this.scrollToPane(pos, true);
  },

  scrollToPane: function(index, first){
    var el = this.element.find(".dv-panes");

    if(index < this.panes.length && index >= 0){
      if(!first && index > 0){
        index = index - (this.options.visiblePanes - 1);
        index = index < 0 ? 0 : index;
      }

      el.animate({scrollLeft: this.panes[index].left});
    }
  },


  open: function(doc, options){
    var panes = this.findDocumentPanes(doc);

    if(panes.length === 0){
      this.addPane(null, doc, options);
    } else {
      this.scrollToPane(panes[0].index);
    }
  },

  // index of null or -1 will add document to the end of list
  // index of 0 will add to the beginning
  addPane: function(index, doc, options, skipScroll){
    var p;

    if(index === null || index < 0){
      index = this.panes.length;
    }
    
    options = $.extend({width: this.docWidth(), height: this.docHeight()}, options || {});
    p = new DocViewer.Pane(index, doc, options);

    this.panes.splice(index, 0, p);
    this.element.find(".dv-panes").append(p.element);

    if(this.documents[doc] !== undefined){
      this.documents[doc]++;
    } else {
      this.documents[doc] = 1;
    }

    this.redraw(index, true);

    if(!skipScroll && this.options.scrollOnOpen && !this.isPaneVisible(index)){
      this.scrollToPane(index, false);
    }
  },

  removePane: function(index){
    var w = this,
        p = this.panes[index];

    p.close(function(){
      w.panes.splice(index, 1);
      w.documents[p.doc]--;
      w.redraw(index-1);

      w.updateDocumentPaneCount(p.doc);
    });
  },

  removeDocument: function(doc){
    var w = this,
    indexes = [];

    // Remove all panes containing document
    $.each(this.panes, function(i, p){
      if(p && p.doc === doc){
        indexes.push(i);
      }
    });

    $.each(indexes, function(i, p){
        w.removePane(p);
    });
  },

  removeAllPanes: function(){
    $.each(this.panes, function(i, p){
      p.close();
    });

    this.panes = [];
    this.documents = [];
    this.redraw();
  },

    redraw: function(startIndex, resize) {
        var w = this;
        var startIndex = startIndex || 0;
    var resize = resize || true;
    var last = this.panes.length-1;
    this.element.find(".dv-window-name").html(this.name());

    // Ensure document list is up to date
    this.redrawDocumentList();

    $.each(this.panes, function(i, p){
      var left = 0;
      p.index = i;

      if(resize === true){
        p.resize(w.docWidth(), w.docHeight());
      }

      // Ensure we calculate left (this is used for maximize to restore position)
      if(i > 0){
        left = w.panes[i-1].left + w.docWidth() + w.options.marginRight;
      }

      p.left = left;

      // Only reposition elements at or after startIndex
      if(i >= startIndex){
        p.element.css('left', p.left);
      }

      // Enable / Disable move controls
      if(i == 0){
        p.element.find(".dv-move-left").addClass("disabled");
      } else {
        p.element.find(".dv-move-left").removeClass("disabled");
      }

      if(i == last){
        p.element.find(".dv-move-right").addClass("disabled");
      } else {
        p.element.find(".dv-move-right").removeClass("disabled");
      }
    });

    // Ensure Left/Right scroll icons are up to date
    this.redrawScrollControls();
  },

  redrawDocumentList: function(){
    var list = this.element.find(".dv-document-list ul"),
    parent = list.parent();
    w = this;
    list.empty();

    parent.height(this.element.height() - 33);

    if(parent.is(':visible')){
      this.element.find(".dv-panes").css({left: parent.outerWidth()+"px", width: this.element.width() - parent.outerWidth()+"px"});
    } else {
      this.element.find(".dv-panes").css({left: 0, width: "100%"});
    }

    $.each(Object.keys(this.documents), function(i, doc){
      var panes = w.findDocumentPanes(doc);

      if(panes.length > 0){
        list.append($("<li data-pane-id='" + panes[0].index +"'><div class='dv-name'><i class='fa fa-file-o'></i>&nbsp;&nbsp;" + panes[0].name() + "</div></li>"));
      }
    });
  },

  redrawScrollControls: function(){
    // Left
    if(this.panes.length > 0 && !this.isPaneVisible(0)){
      this.element.find(".dv-scroll-left").removeClass("disabled");
    } else {
      this.element.find(".dv-scroll-left").addClass("disabled");
    }

    // Right
    if(this.panes.length > 0 && !this.isPaneVisible(this.panes.length-1)){
      this.element.find(".dv-scroll-right").removeClass("disabled");
    } else {
      this.element.find(".dv-scroll-right").addClass("disabled");
    }
  },

  setVisiblePanes: function(panes){
    this.options.visiblePanes = panes;
    this.redraw();

    // Save setting
    $.cookie('visiblePanes', panes, { expires: 365, path: '/' });

    $(".dv-pane-controls a").removeClass("active");

    switch(panes){
      case 1:
        this.element.find(".dv-pane-controls a.dv-one-pane").addClass("active");
        break;
      case 2:
        this.element.find(".dv-pane-controls a.dv-two-pane").addClass("active");
        break;
      case 3:
        this.element.find(".dv-pane-controls a.dv-three-pane").addClass("active");
        break;
    }

    // Ensure we shift to the start of the first pane, we dont want to be viewing portions of panes
    var pos = this.firstVisiblePane();
    this.scrollToPane(pos, true);
  },

  findDocumentPanes: function(doc){
    return $.grep(this.panes, function(p, i){ return p.doc === doc; });
  },

  groupDocumentPanes: function(doc, index){
    var panes = this.findDocumentPanes(doc),
    i=0;

    if(index === null){
      index = 0;
    }

    // Remove Panes
    for(i=0; i < this.panes.length; i++){
      if(this.panes[i].doc === doc){
        this.panes.splice(i, 1);

        if(i < index){
          index--;
        }

        i--;
      }
    }

    // Insert Panes at new location
    for(i=0; i < panes.length; i++){
      this.panes.splice(index, 0, panes[i]);
    }

    this.redraw(0);
  },

  updateDocumentPaneCount: function(doc){
    var panes = this.findDocumentPanes(doc),
    count = this.documents[doc];

    $.each(panes, function(i, p){
      p.element.find('.dv-single, .dv-duplicate, .dv-triplicate').removeClass('active');

      switch(count){
        case 1:
          p.element.find('.dv-single').addClass('active');
        break;

        case 2:
          p.element.find('.dv-duplicate').addClass('active');
        break;

        case 3:
          p.element.find('.dv-triplicate').addClass('active');
        break;
      }
    });
  },

  name: function(){
    return this.options.name + " - " + this.documentCount() + " Documents, " + this.panes.length + " Panes";
  },

  documentCount: function(){
    var count = 0,
    w = this;

    $.each(Object.keys(this.documents), function(i, doc){
      if(w.documents[doc] > 0){
        count++;
      }
    });

    return count;
  },

  docWidth: function(){
    return Math.floor(this.element.find('.dv-panes').innerWidth() / this.options.visiblePanes) - (this.options.visiblePanes > 1 ? (this.options.marginRight * (this.options.visiblePanes + 1)) : 0);
  },

  docHeight: function(){
    return Math.floor(this.element.innerHeight() - 68);
  },

  defaultOptions: {
    name: "Document Viewer",
    width: "100%",
    height: "",
    visiblePanes: 2,
    marginRight: 1,
    pane: {},
    scrollOnOpen: true,
  }
};

// Pane
DocViewer.Pane = function (index, doc, options) {
  this.index = index;
  this.doc = doc;
  this.options = $.extend({}, this.defaultOptions, options || {});
  this.element = this.createElement();

  this.initialize();
  this.open(doc);
  this.resize(this.options.width, this.options.height);
};

DocViewer.Pane.prototype = {
    initialize: function(){
        this.element.data('dv-pane', this);
    },
    
    createElement: function(){
        // Base element
        var el = $("<div class='dv-pane'>" +
                   "<div class='dv-toolbar'>" +
                   "<div class='dv-name'></div>" +
                   "<div class='dv-controls'>" +
                   "<span class='dv-popout' title='Open this document in a new window'>↗</span>" +
                   "<span class='dv-workflow' title='Add to workflow'>W</span>" +
                   "<span class='dv-note' title='Add Note'>N</span>" +
                   "<div class='separator'></div>" +
                   "<i class='fa fa-file-o dv-single active' title='Single document view'>&nbsp;1</i>" +
                   "<i class='fa fa-files-o dv-duplicate' title='Duplicate document view'>&nbsp;2</i>" +
                   "<i class='fa fa-files-o dv-triplicate' title='Triplicate document view'>&nbsp;3</i>" +
                   "<i class='fa fa-chevron-left dv-move-left' title='Move this document to the left'></i>" +
                   "<i class='fa fa-chevron-right dv-move-right' title='Move this document to the right'></i>" +
                   "<i class='fa fa-expand dv-fullscreen' title='Open this document in the entire window'></i>" +
                   "<i class='fa fa-external-link dv-popout' title='Open this document in a new window'></i>" +
                   "<i class='fa fa-compress dv-minimize' title='Exit fullscreen mode' style='display: none'></i>" +
                   "<i class='fa fa-times-circle dv-close' title='Close this document'></i>" +
                   "</div>" +
                   "</div>" +
                   "<iframe allowfullscreen webkitallowfullscreen></iframe>" +
                   "</div>");

        // Set document src
        el.find('iframe').css('width', this.options.width).css('height', this.options.height);
    
        return el;
    },

    open: function(doc){
        this.doc = doc;
        this.element.find('iframe').attr('src', this.getOpenUrl());
        this.element.find('.dv-toolbar .dv-name').html(this.name());
    },
    
    close: function(callback){
        var el = this.element;
        this.element.removeData('dv-pane');

        this.element.fadeOut(100, function(){
            el.remove();
            
            if(callback){
                callback();
            }
        });
    },
    
    hide: function(duration){
        this.element.hide(duration);
    },
    
    show: function(duration){
        this.element.show(duration);
    },
    
    fullscreen: function(){
        var windowEl = this.element.closest('.dv-window'),
        w = windowEl.data('dv-window'),
        el = this.element;
        
        el.animate({left: 0}, 200, function(){
            el.find('iframe').animate({width: windowEl.width(), height: w.docHeight() || w.options.minHeight}, 200, function(){
                // Hide all controls except minimize
                el.find('.dv-controls i').hide();
                el.find('.dv-controls .dv-minimize').show();
                el.find('.dv-controls .dv-close').show();
            });
        });
    },
    
    minimize: function(){
        var el = this.element,
        p = this;
        
        el.find('iframe').animate({width: p.options.width, height: p.options.height}, 200, function(){
            el.animate({left: p.left}, 200, function(){
                // Show all controls except minimize
                el.find('.dv-controls i').show();
                el.find('.dv-controls .dv-minimize').hide();
            });
        });
    },
    
    resize: function(width, height){
        var el = this.element;
        this.options.width = width;
        this.options.height = height;
        
        //el.find('.dv-name').css('width', width-300);
        el.find('iframe').css('width', width).css('height', height);
    },
    
    getOpenUrl: function(){
        var url = this.doc;
        
        return url;
        
    },
    
    name: function(){
        return decodeURIComponent(this.options.name) || this.doc;
    },
    
    defaultOptions: {
        width: '100%',
        height: '800px',
        minHeight: '600px',
        page: 1,
        search: '',
        highlight: '',
        view: 'FitV',
        scrollbar: 1,
        toolbar: 1,
        statusbar: 1,
        name: "",
        navpanes: 0,
        zoom: 100
    }
};
