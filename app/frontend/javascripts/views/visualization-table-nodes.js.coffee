Handsontable            = require './../dist/handsontable.full.js'
VisualizationTableBase  = require './visualization-table-base.js'

class VisualizationTableNodes extends VisualizationTableBase

  el:               '.visualization-table-nodes'
  nodes_types:      null
  tableColHeaders:  ['', '', 'Node', 'Type', 'Description', 'Visible', 'Image', '<a class="add-custom-column" href="#" data-toggle="modal" data-target="#table-add-column-modal" title="Add Custom Column"></a>']
  columns:          {
    'delete'      : 0
    'duplicate'   : 1
    'node'        : 2
    'type'        : 3
    'description' : 4
    'visible'     : 5
    'image'       : 6
  }

  constructor: (@model, @collection) ->
    super @model, @collection, 'node'
    # Override Table Options
    @table_options.colHeaders  = @tableColHeaders
    @table_options.columns     = @getTableColumns()
    @$el.find('.add-custom-column').click @onShowAddCustomColumnModal
    $('#add-custom-column-form').submit   @onAddCustomColumn

  onSync: =>
    console.log 'onSync', @model
    @getNodesTypes()

  # Setup Handsontable columns options
  getTableColumns: =>
    return [
      { 
        data: ''
        readOnly: true
        renderer: @rowDeleteRenderer
      },
      { 
        data: '',
        readOnly: true,
        renderer: @rowDuplicateRenderer
      },
      { 
        data: 'name' 
      },
      { 
        data: 'node_type',
        type: 'autocomplete'
        source: @nodes_types
        strict: false
      },
      { 
        data: 'description'
        readOnly: true
        renderer: @rowDescriptionRenderer
        #data: 'description'
        #renderer: 'html'
      },
      { 
        data: 'visible' 
        type: 'checkbox'
        renderer: @rowVisibleRenderer
      },
      {
        data: ''
        readOnly: true
        renderer: @rowImageRenderer
      },
      { 
        data: ''
        readOnly: true
      }
    ]

  getNodesTypes: =>
    #console.log 'getNodesTypes'
    $.ajax {
      url: '/api/visualizations/'+$('body').data('id')+'/nodes/types.json'
      dataType: 'json'
      success: @onNodesTypesSucess
    }

  onNodesTypesSucess: (response) =>
    @nodes_types = response
    @setNodesTypesSource()
    @setupTable()
    # Add on beforeKeyDown handler to change key ENTER behavior
    @table.addHook 'beforeKeyDown', @onBeforeKeyDown
    # Add Node Btn Handler
    $('#visualization-add-node-btn').click (e) =>
      e.preventDefault()
      @addRow()

  # Method called from parent class `VisualizationTableBase`
  addModel: (index) ->
    # We need to set `wait = true` to wait for the server before adding the new model to the collection
    # http://backbonejs.org/#Collection-create
    model = @collection.create {dataset_id: @model.get('dataset_id'), 'visible': true, wait: true}
    # We wait until model is synced in server to get its id
    @collection.once 'sync', () ->
      @table.setDataAtRowProp index, 'id', model.id
      # set duplicated values
      if @duplicate
        if @duplicate.get('name')
          @table.setDataAtRowProp index, 'name', @duplicate.get('name')+' (1)'
        if @duplicate.get('node_type')
          @table.setDataAtRowProp index, 'node_type', @duplicate.get('node_type')
        if @duplicate.get('description')
          @table.setDataAtRowProp index, 'description', @duplicate.get('description')
        @table.setDataAtRowProp index, 'visible', @duplicate.get('visible')
        console.log 'now set duplicate values'
        @duplicate = null
      else
        @table.setDataAtRowProp index, 'visible', true
    , @
          
  # Method called from parent class `VisualizationTableBase`
  updateModel: (change) =>
    index = change[0]
    key   = change[1]
    value = change[3]
    # Get model id in order to acced to model in Collection
    model_id = @getIdAtRow index
    if model_id
      model = @collection.get model_id
      # Add new node_type to nodes_types array
      if key == 'node_type' && !_.contains(@nodes_types, value)
        @addNodesType value
      obj = {}
      obj[ key ] = value
      # Save model with updated attributes in order to delegate in Collection trigger 'change' events
      model.save obj

  addNodesType: (type) ->
    @nodes_types.push type
    @setNodesTypesSource()

  # Set 'Node Type' column source in table_options
  setNodesTypesSource: ->
    @table_options.columns[ @columns.type ].source = @nodes_types

  # Show Add Custom Column Modal handler
  onShowAddCustomColumnModal: (e) ->
    e.preventDefault()
    
  # Show Add Custom Column Modal handler
  onAddCustomColumn: (e) =>
    e.preventDefault()
    # get column name from form input text
    column_name = $(e.target).find('#add-custom-column-name').val()
    # get penultimate position in tableColHeaders array
    index = @tableColHeaders.length-1
    # insert column name at penultimate position in tableColHeaders array
    @tableColHeaders.splice index, 0, column_name
    @table_options.colHeaders = @tableColHeaders
    # insert new column data at penultimate position in columns array
    @table_options.columns.splice index, 0, { data: column_name.replace(/\s+/g, '-').toLowerCase() } 
    console.log 'onAddCustomColumn', e.target, @table_options
    # update table options
    if @table
      @table.updateSettings @table_options
    # hide modal
    $('#table-add-column-modal').modal 'hide'

  onBeforeKeyDown: (e) =>
    selected = @table.getSelected()
    # ENTER or SPACE keys
    if e.keyCode == 13 or e.keyCode == 32
      # In Delete column launch delete modal
      if selected[1] == @columns.delete and selected[3] == @columns.delete
        e.stopImmediatePropagation()
        e.preventDefault()
        @showDeleteModal selected[0]
      # In Duplicate column add duplicated row
      else if selected[1] == @columns.duplicate and selected[3] == @columns.duplicate
        e.stopImmediatePropagation()
        e.preventDefault()
        @duplicateRow selected[0]
      # In Description column launch description modal
      else if selected[1] == @columns.description and selected[3] == @columns.description
        e.stopImmediatePropagation()
        e.preventDefault()
        @showDescriptionModal selected[0]
      # In Image column launch image modal
      else if selected[1] == @columns.image and selected[3] == @columns.image
        e.stopImmediatePropagation()
        e.preventDefault()
        @showImageModal selected[0]

  # Function to show modal with description edit form
  showDescriptionModal: (index) =>
    console.log 'showDescriptionModal', index
    $modal = $('#table-description-modal')
    # Load description edit form via ajax in modal
    $modal.find('.modal-body').load '/nodes/'+@getIdAtRow(index)+'/edit/description/', () =>
      # Add on submit handler to save new description via model
      $modal.find('.form-default').on 'submit', (e) =>
        e.preventDefault()
        @table.setDataAtRowProp index, 'description', $modal.find('#node_description').val()
        $modal.modal 'hide'
    # Show modal
    $modal.modal 'show'

  # Function to show modal with image edition
  showImageModal: (index) =>
    console.log 'showImageModal', index
    $modal = $('#table-image-modal')

    # Show modal
    $modal.modal 'show'

  # Custom Renderer for description cells
  rowDescriptionRenderer: (instance, td, row, col, prop, value, cellProperties) =>
    # Add delete icon
    link = document.createElement('A')
    link.className = if value then 'icon-table' else 'icon-plus'
    link.innerHTML = link.title = 'Edit Description'
    Handsontable.Dom.empty(td)
    td.appendChild(link)
    # Add description modal on click event or keydown (enter or space)
    Handsontable.Dom.addEvent link, 'click', (e) =>
      e.preventDefault()
      @showDescriptionModal row
    return td

  # Custom Renderer for visible cells
  rowVisibleRenderer: (instance, td, row, col, prop, value, cellProperties) =>
    # We keep checkbox render in order to toogle value with enter key
    Handsontable.renderers.CheckboxRenderer.apply(this, arguments)
    # Add visible icon link
    link = document.createElement('A')
    link.className = if value then 'icon-visible active' else 'icon-visible'
    link.innerHTML = link.title = 'Node Visibility'
    td.appendChild(link)
    # Toggle visibility value on click
    Handsontable.Dom.addEvent link, 'click', (e) =>
      e.preventDefault()
      instance.setDataAtCell(row, col, !value)
    return td

  # Custom Renderer for image cells
  rowImageRenderer: (instance, td, row, col, prop, value, cellProperties) =>
    # We keep checkbox render in order to toogle value with enter key
    Handsontable.renderers.CheckboxRenderer.apply(this, arguments)
    # Add visible icon link
    link = document.createElement('A')
    link.className = if value then 'icon-image active' else 'icon-image'
    link.innerHTML = link.title = 'Node Image'
    td.appendChild(link)
    # Show image modal on click
    Handsontable.Dom.addEvent link, 'click', (e) =>
      e.preventDefault()
      @showImageModal row
    return td

module.exports = VisualizationTableNodes
