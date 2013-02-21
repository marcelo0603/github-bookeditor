# # Page Controllers
#
# This module sets up page regions (ie header, footer, sidebar, etc),
# route listeners, and updates the URL and DOM with the correct views
#
# This makes it easier in other parts of the code to 'Go back to the Workspace'
# or "Edit this content" when clicking on a link.
define [
  'jquery'
  'backbone'
  'marionette'
  'atc/auth'
  'atc/models'
  # There is a cyclic dependency between views and controllers
  # so we use the `exports` module to get around that problem.
  'atc/views'
  'hbs!atc/layouts/main'
  'hbs!atc/layouts/book-view'
  'hbs!atc/layouts/content'
  'hbs!atc/layouts/workspace'
  'exports'
  'i18n!atc/nls/strings'
], (jQuery, Backbone, Marionette, Auth, Models, Views, LAYOUT_MAIN, LAYOUT_BOOK_VIEW, LAYOUT_CONTENT, LAYOUT_WORKSPACE, exports, __) ->

  mainRegion = new Marionette.Region
    el: '#main'


  # Use a custom region manager so CSS3 transitions can be triggered
  HidingRegion = Marionette.Region.extend
    onShow: ->  @$el.removeClass 'hidden'
    onClose: -> @ensureEl(); @$el.addClass 'hidden'

  # ## Layouts
  # The `MainLayout` contains all areas of the page that do not change
  MainLayout = Marionette.Layout.extend
    template: LAYOUT_MAIN
    regionType: HidingRegion
    regions:
      back:         '#layout-main-back'
      toolbar:      '#layout-main-toolbar'
      auth:         '#layout-main-auth'
      sidebar:      '#layout-main-sidebar'
      area:         '#layout-main-area'
  mainLayout = new MainLayout()
  # Keep the regions so views can just update the regions they need
  mainToolbar = mainLayout.toolbar
  mainSidebar = mainLayout.sidebar
  mainArea = mainLayout.area

  # Used when editing a single piece of content.
  # Contains additional areas for editing metadata using separate views
  ContentLayout = Marionette.Layout.extend
    template: LAYOUT_CONTENT
    regions:
      title:        '#layout-title'
      body:         '#layout-body'
      # Specific to content
      metadata:     '#layout-metadata'
      roles:        '#layout-roles'
  contentLayout = new ContentLayout()


  # ## Main Controller
  # Changes all the regions on the page to begin editing a new/existing
  # piece of content.
  #
  # If another part of the code wants to create/edit content
  # it should call these methods instead of changing the URL directly.
  # (depending on the browser the URLs could start with a hash so anchor links won't work)
  #
  # Methods on this object can be called directly and will update the URL.
  mainController =
    # Begin monitoring URL changes and match the current route
    # In here so App can call it once it has completed loading
    start: ->
      mainRegion.show mainLayout
      mainLayout.auth.show new Views.AuthView {model: Auth}

      mainLayout.back.ensureEl() # Not sure why this particular region needs this...
      mainLayout.back.$el.on 'click', -> Backbone.history.history.back()


      # Hide the regions if they are not being used
      mainSidebar.onClose()
      mainArea.onClose()
      # Start URL Routing
      Backbone.history.start()

    # Provide the main region that this controller uses.
    # Useful for applications that want to extend this editor.
    getRegion: -> mainRegion

    # ### Show Workspace
    # Shows the workspace listing and updates the URL
    workspace: ->
      mainToolbar.close()
      # List the workspace
      workspace = new Models.SearchResults()
      workspace = new Models.FilteredCollection null, {collection: workspace}

      view = new Views.SearchBoxView {model: workspace}
      mainToolbar.show view

      view = new Views.SearchResultsView {collection: workspace}
      mainArea.show view

      # Update the URL
      Backbone.history.navigate 'workspace'

      workspace.on 'change', ->
        view.render()

    # ### Create new content
    # Calling this method directly will start editing a new piece of content
    # and will update the URL
    createContent: ->
      content = new Models.Content()
      @_editContent content
      # Update the URL
      Backbone.history.navigate 'content'

    # ### Edit existing content
    # Calling this method directly will start editing an existing piece of content
    # and will update the URL.
    editModelId: (id) ->
      model = Models.ALL_CONTENT.get id
      return console.warn 'Could not find content with that id' if not model
      @editModel model

    # Edit a piece of content.
    # Called when a link is clicked in the workspace list or in a search result window
    #
    # Dispatches based on the contents' `mediaType`
    editModel: (model) ->
      switch model.get 'mediaType'
        when 'text/x-module' then @editContent model
        when 'text/x-collection' then @showBook model
        else throw 'BUG: Invalid mediaType'

    # Show a book TOC in the left sidebar
    showBook: (model) ->
      model.deferred (err) =>
        return alert 'Problem connecting to server' if err
        mainToolbar.close()
        mainArea.close()


        view = new Views.BookView {model: model}
        mainSidebar.show view

    # Edit a book in the main area
    editBook: (model) ->
      model.deferred (err) =>
        return alert 'Problem connecting to server' if err
        mainToolbar.close()

        view = new Views.BookAddContentView {model: model}
        mainSidebar.show view

        view = new Views.BookEditView {model: model}
        mainArea.show view

    # Edit a piece of HTML content
    editContent: (content) ->
      # ## Bind Metadata Dialogs
      mainArea.show contentLayout

      # Load the various views:
      #
      # - The Aloha toolbar
      # - The editable title at the top of the document under the toolbar
      # - The metadata/roles accordion
      # - The main editable content area

      # Wrap each 'tab' in the accordion with a Save/Cancel dialog
      configAccordionDialog = (region, view) ->
        dialog = new Views.DialogWrapper {view: view}
        region.show dialog
        # When save/cancel are clicked collapse the accordion
        dialog.on 'saved',     => region.$el.parent().collapse 'hide'
        dialog.on 'cancelled', => region.$el.parent().collapse 'hide'

      # Set up the metadata dialog
      configAccordionDialog contentLayout.metadata, new Views.MetadataEditView {model: content}
      configAccordionDialog contentLayout.roles,    new Views.RolesEditView {model: content}

      view = new Views.ContentToolbarView(model: content)
      mainToolbar.show view

      view = new Views.TitleEditView(model: content)
      contentLayout.title.show view

      # Enable the tooltip letting the user know to edit
      contentLayout.title.$el.popover
        trigger: 'hover'
        placement: 'right'
        content: __('Click to change title')

      view = new Views.ContentEditView(model: content)
      contentLayout.body.show view

      # Update the URL
      Backbone.history.navigate "content/#{content.get 'id'}"

  # ## Bind Routes
  ContentRouter = Marionette.AppRouter.extend
    controller: mainController
    appRoutes:
      '':             'workspace' # Show the workspace list of content
      'workspace':    'workspace'
      'content':      'createContent' # Create a new piece of content
      'content/:id':  'editModelId' # Edit an existing piece of content

  # Start listening to URL changes
  new ContentRouter()

  # Because of cyclic dependencies we tack on all of the
  # controller methods onto the exported object instead of
  # just returning the controller object
  jQuery.extend(exports, mainController)
