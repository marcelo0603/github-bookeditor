define [
  'jquery'
  'marionette'
  'cs!views/workspace/content/content-edit'
  'hbs!templates/workspace/content/layouts/editor'
], ($, Marionette, ContentEditView, editorTemplate) ->

  return class EditorLayout extends Marionette.Layout
    template: editorTemplate

    regions:
      edit: '#layout-body'

    onRender: () ->
      @edit.show(new ContentEditView({model: @model}))

      # FIXME. Set the title of the edited content. This could likely be
      # done better, and would normally be unnecessary because this info is
      # also in @title above, but presently this is being hidden in css pending
      # other changes, so we need this feedback here.
      $('#module-title-indicator').text(@model.get('title'))
