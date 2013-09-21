define [
  'underscore'
  'backbone'
  'cs!collections/content'
  'cs!models/content/inherits/container'
], (_, Backbone, allContent, BaseContainerModel) ->

  return class Book extends BaseContainerModel
    defaults:
      title: 'Untitled Book'

    mediaType: 'application/vnd.org.cnx.collection'
    accept: ['application/vnd.org.cnx.module'] # Module


    initialize: (options) ->
      super(options)

      setBody = (options) =>
        if !options.parse
          @set('body', @toHTML(), options)

      children = @getChildren()
      # When new content gets an id, reserialize the ToC
      children.on 'change:id',  (model, value, options) => setBody({}) # Do not send options because parse:true will be set since the POST returned the id causing this event to fire
      # When new content is added make sure allContent has the new model. TODO: move this into the constructor in mediaTypes or something
      children.on 'add',        (model, collection, options)  => allContent.add(model)
      # Update the ToC when elements are added or removed
      children.on 'add remove', (model, collection, options)  => setBody(options)
      # Update the ToC when the overridden title is changed (only a 'change' event is fired ;(
      children.on 'change reset', (model, options)            => setBody(options)

    # Helper function to parse html-encoded data.
    #
    # Assumptions:
    # - body is a flat list (not a tree)
    # - `<nav>` is the root element
    parseHTML: (html) ->
      if typeof html isnt 'string' then return []

      results = []

      $(html).find('> ol > li').each (index, el) ->
        $el = $(el)
        $node = $el.children().eq(0)

        if $node.is('a')
          id = $node.attr('href')
          title = $node.text()

        # Only remember the title if it's overridden
        if not title or $node.hasClass('autogenerated-text')
          results.push({id: id})
        else
          results.push({id: id, title: title})

      return results


    # Currently, a Book does not support full Tree editing
    # so generate a naive list.
    toHTML: () ->
      children = @getChildren()

      overriddenTitles = children.titles # Overridden titles are stored in an Object dangling off the Collection

      listItems = children.map (child) ->
        # If this node has an overridden title, look it up and use it here
        if child.isNew()
          console.warn 'BUG: Saving collections with new unsaved modules is not supported'
        else
          overriddenTitle = _.find overriddenTitles, (item) -> item.id == child.id and item.title
          if overriddenTitle
            return "<li><a href='#{child.id}'>#{overriddenTitle.title}</a></li>"
          else
            return "<li><a href='#{child.id}' class='autogenerated-text'>#{child.get('title')}</a></li>"

      return """
        <nav>
          <ol>
            #{listItems.join('\n')}
          </ol>
        </nav>
      """

    parse: (json) ->
      childIdsAndTitles = @parseHTML(json.body)

      # Look up each entry in Contents
      childModels = _.map childIdsAndTitles, (item) =>
        @_ALL_CONTENT_HACK.get({id: item.id})

      @getChildren().reset(childModels, {parse:true})
      delete json.body


      # Squirrel away the overridden titles
      @getChildren().titles = childIdsAndTitles

      return json



    toJSON: () ->
      json = super()
      delete json.contents
      return json
