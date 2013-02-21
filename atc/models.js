// Generated by CoffeeScript 1.3.3
(function() {

  define(['exports', 'jquery', 'backbone', 'i18n!atc/nls/strings'], function(exports, jQuery, Backbone, __) {
    var ALL_CONTENT, AllContent, BaseContent, Book, Content, Deferrable, DeferrableCollection, MEDIA_TYPES, MediaTypes, SearchResults, deferred;
    MediaTypes = Backbone.Collection.extend({
      model: Backbone.Model.extend({
        sync: function() {
          throw 'This model cannot be syncd';
        }
      }),
      sync: function() {
        throw 'This model cannot be syncd';
      }
    });
    MEDIA_TYPES = new MediaTypes();
    BaseContent = Backbone.Model.extend({
      initialize: function() {
        var key, mediaType, mediaTypeConfig, proto, value;
        mediaType = this.get('mediaType');
        if (!mediaType) {
          throw 'BUG: No mediaType set';
        }
        if (!MEDIA_TYPES.get(mediaType)) {
          throw 'BUG: No mediaType not registered';
        }
        mediaTypeConfig = MEDIA_TYPES.get(mediaType);
        proto = mediaTypeConfig.get('constructor').prototype;
        for (key in proto) {
          value = proto[key];
          this[key] = value;
        }
        return proto.initialize.apply(this, arguments);
      }
    });
    AllContent = Backbone.Collection.extend({
      model: BaseContent
    });
    ALL_CONTENT = new AllContent();
    deferred = function(cb) {
      var _this = this;
      if (this.loaded) {
        return cb(null, this);
      }
      if (!this._defer) {
        this._defer = this.fetch();
      }
      return this._defer.done(function(value) {
        _this.loaded = true;
        _this._defer = null;
        return cb(null, _this);
      }).fail(function(err) {
        _this.loaded = false;
        _this._defer = null;
        return cb(err, _this);
      });
    };
    Deferrable = Backbone.Model.extend({
      deferred: function() {
        return deferred.apply(this, arguments);
      }
    });
    DeferrableCollection = Backbone.Collection.extend({
      deferred: function() {
        return deferred.apply(this, arguments);
      }
    });
    exports.FilteredCollection = Backbone.Collection.extend({
      defaults: {
        collection: null
      },
      setFilter: function(str) {
        var models,
          _this = this;
        if (this.filterStr === str) {
          return;
        }
        this.filterStr = str;
        models = this.collection.filter(function(model) {
          return _this.isMatch(model);
        });
        return this.reset(models);
      },
      isMatch: function(model) {
        if (!this.filterStr) {
          return true;
        }
        return model.get('title').toLowerCase().search(this.filterStr.toLowerCase()) >= 0;
      },
      initialize: function(models, options) {
        var _this = this;
        this.filterStr = options.filterStr || '';
        this.collection = options.collection;
        if (!this.collection) {
          throw 'BUG: Cannot filter on a non-existent collection';
        }
        this.add(this.collection.filter(function(model) {
          return _this.isMatch(model);
        }));
        this.collection.on('add', function(model) {
          if (_this.isMatch(model)) {
            return _this.add(model);
          }
        });
        this.collection.on('remove', function(model) {
          return _this.remove(model);
        });
        return this.collection.on('change', function(model) {
          if (_this.isMatch(model)) {
            return _this.add(model);
          } else {
            return _this.remove(model);
          }
        });
      }
    });
    Content = Deferrable.extend({
      defaults: {
        title: __('Untitled'),
        subjects: [],
        keywords: [],
        authors: [],
        copyrightHolders: [],
        language: ((typeof navigator !== "undefined" && navigator !== null ? navigator.userLanguage : void 0) || (typeof navigator !== "undefined" && navigator !== null ? navigator.language : void 0) || 'en').toLowerCase()
      },
      url: function() {
        if (this.get('id')) {
          return "" + URLS.CONTENT_PREFIX + (this.get('id'));
        } else {
          return URLS.CONTENT_PREFIX;
        }
      },
      validate: function(attrs) {
        var isEmpty;
        isEmpty = function(str) {
          return str && !str.trim().length;
        };
        if (isEmpty(attrs.body)) {
          return 'ERROR_EMPTY_BODY';
        }
        if (isEmpty(attrs.title)) {
          return 'ERROR_EMPTY_TITLE';
        }
        if (attrs.title === __('Untitled')) {
          return 'ERROR_UNTITLED_TITLE';
        }
      }
    });
    Book = Deferrable.extend({
      defaults: {
        manifest: null,
        navTree: null
      },
      parseNavTree: function(li) {
        var $a, $li, $ol, obj;
        $li = jQuery(li);
        $a = $li.children('a, span');
        $ol = $li.children('ol');
        obj = {
          id: $a.attr('href') || $a.data('id'),
          title: $a.text()
        };
        obj["class"] = $a.data('class') || $a.not('span').attr('class');
        if ($ol[0]) {
          obj.children = (function() {
            var _i, _len, _ref, _results;
            _ref = $ol.children();
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              li = _ref[_i];
              _results.push(this.parseNavTree(li));
            }
            return _results;
          }).call(this);
        }
        return obj;
      },
      initialize: function() {
        var _this = this;
        this.manifest = new Backbone.Collection();
        this.manifest.on('change:title', function(model, newValue, oldValue) {
          var navTree, node, recFind;
          navTree = _this.getNavTree();
          recFind = function(nodes) {
            var node, _i, _len;
            for (_i = 0, _len = nodes.length; _i < _len; _i++) {
              node = nodes[_i];
              if (model.id === node.id) {
                return node;
              }
              if (node.children) {
                return recFind(node.children);
              }
            }
          };
          node = recFind(navTree);
          if (!node) {
            throw 'BUG: There is an entry in the tree but no corresponding model in the manifest';
          }
          node.title = newValue;
          return _this.set('navTree', navTree);
        });
        this.manifest.on('add', function(model) {
          return ALL_CONTENT.add(model);
        });
        this.on('change:navTree', function(model, navTree) {
          var recAdd;
          recAdd = function(nodes) {
            var contentModel, node, _i, _len, _results;
            _results = [];
            for (_i = 0, _len = nodes.length; _i < _len; _i++) {
              node = nodes[_i];
              if (node.id) {
                ALL_CONTENT.add({
                  id: node.id,
                  title: node.title,
                  mediaType: 'text/x-module'
                });
                contentModel = ALL_CONTENT.get(node.id);
                _this.manifest.add(contentModel);
              }
              if (node.children) {
                _results.push(recAdd(node.children));
              } else {
                _results.push(void 0);
              }
            }
            return _results;
          };
          if (navTree) {
            return recAdd(navTree);
          }
        });
        return this.trigger('change:navTree', this, this.getNavTree());
      },
      prependNewContent: function(config) {
        var b, navTree, newContent, uuid;
        uuid = b = function(a) {
          if (a) {
            return (a ^ Math.random() * 16 >> a / 4).toString(16);
          } else {
            return ([1e7] + -1e3 + -4e3 + -8e3 + -1e11).replace(/[018]/g, b);
          }
        };
        if (!config.id) {
          config.id = uuid();
        }
        ALL_CONTENT.add(config);
        newContent = ALL_CONTENT.get(config.id);
        navTree = this.getNavTree();
        navTree.unshift({
          id: config.id,
          title: config.title
        });
        return this.set('navTree', navTree);
      },
      getNavTree: function(tree) {
        return JSON.parse(JSON.stringify(this.get('navTree')));
      }
    });
    SearchResults = DeferrableCollection.extend({
      defaults: {
        parameters: []
      }
    });
    MEDIA_TYPES.add({
      id: 'text/x-module',
      constructor: Content
    });
    MEDIA_TYPES.add({
      id: 'text/x-collection',
      constructor: Book
    });
    exports.ALL_CONTENT = ALL_CONTENT;
    exports.MEDIA_TYPES = MEDIA_TYPES;
    exports.SearchResults = SearchResults;
    return exports;
  });

}).call(this);
