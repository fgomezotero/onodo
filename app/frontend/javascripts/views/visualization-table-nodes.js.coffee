Handsontable                = require './../dist/handsontable.full.js'
VisualizationTableBase      = require './visualization-table-base.js'
VisualizationModalNodeImage = require './visualization-modal-node-image.js'

class VisualizationTableNodes extends VisualizationTableBase

  el:                '.visualization-table-nodes'
  nodes_types:       null
  table_col_headers: null
  columns:
    'delete'         : 0
    'duplicate'      : 1
    'node'           : 2
    'type'           : 3
    'description'    : 4
    'visible'        : 5
    'image'          : 6
  network_analysis_names:
    '_cluster':
      'en': 'clusters'
      'es': 'grupos'
    '_degree':
      'en': 'connections'
      'es': 'conexiones'
    '_relevance':
      'en': 'relevance'
      'es': 'relevancia'
    '_betweenness':
      'en': 'betweenness'
      'es': 'intermediación'
    '_closeness':
      'en': 'closeness'
      'es': 'cercanía'
    '_coreness':
      'en': 'coreness'
      'es': 'nuclearidad'



  constructor: (@model, @collection) ->
    # Set columns names based on current language
    if $('body').hasClass('lang-en')
      @table_col_headers = ['', '', 'Node', 'Type', 'Description', 'Visible', 'Image']
    else
      @table_col_headers = ['', '', 'Nodo', 'Tipo', 'Descripción', 'Visible', 'Imagen']
    super @model, @collection, 'node'    # Add Image Modal View
    @visualizationModalNodeImage = new VisualizationModalNodeImage
    @visualizationModalNodeImage.on 'update',  @onVisualizationModalNodeImageUpdate
    @visualizationModalNodeImage.on 'delete',  @onVisualizationModalNodeImageDelete
    # Custom Column Managment
    $('#add-custom-column-nodes-form').submit @onAddCustomColumn

  render: ->
    super()
    #console.log 'VisualizationTableNodes render'
    # add custom_fields to table if defined
    @setupCustomFields @model.get('node_custom_fields')
    # get node types
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
        data: 'image'
        readOnly: true
        renderer: @rowImageRenderer
      }
    ]

  getNodesTypes: =>
    #console.log 'getNodesTypes'
    $.ajax {
      url: '/api/visualizations/'+@model.id+'/nodes/types.json'
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
  createRow: (index) ->
    # We need to set `wait = true` to wait for the server before adding the new model to the collection
    # http://backbonejs.org/#Collection-create
    row_model = @collection.create {dataset_id: @model.get('dataset_id'), 'visible': true, wait: true}
    # We wait until model is synced in server to get its id
    @collection.once 'sync', () ->
      # set focus on new row name column
      @table.selectCell index, 2
      # set row id
      @table.setDataAtRowProp index, 'id', row_model.id
      # set duplicated values
      if @duplicate
        if @duplicate.get('name')
          @table.setDataAtRowProp index, 'name', @duplicate.get('name')+' (1)'
        if @duplicate.get('node_type')
          @table.setDataAtRowProp index, 'node_type', @duplicate.get('node_type')
        if @duplicate.get('description')
          @table.setDataAtRowProp index, 'description', @duplicate.get('description')
        if @duplicate.get('image')
          @table.setDataAtRowProp index, 'image', @duplicate.get('image')
        @table.setDataAtRowProp index, 'visible', @duplicate.get('visible')
        @duplicate = null
      else
        @table.setDataAtRowProp index, 'visible', true
    , @
          
  # Method called from parent class `VisualizationTableBase`
  updateCell: (change) =>
    index = change[0]
    key   = change[1]
    value = change[3]
    # Get model id in order to access to model in Collection
    cell_id = @getIdAtRow index
    if cell_id
      cell_model = @collection.get cell_id
      if cell_model
        # Add new node_type to nodes_types array
        if key == 'node_type' && !_.contains(@nodes_types, value)
          @addNodesType value
        obj = {}
        obj[ key ] = value
        #console.log 'updateCell', obj, cell_model
        # Save model with updated attributes in order to delegate in Collection trigger 'change' events
        cell_model.save obj, {patch: true}

  addNodesType: (type) ->
    @nodes_types.push type
    @setNodesTypesSource()

  # Set 'Node Type' column source in table_options
  setNodesTypesSource: ->
    @table_options.columns[ @columns.type ].source = @nodes_types

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
    #console.log 'showDescriptionModal', index
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
    @visualizationModalNodeImage.show index, @getIdAtRow(index)

  # Update listener for Image Edition Modal
  onVisualizationModalNodeImageUpdate: (e) =>
    #console.log 'onVisualizationModalNodeImageUpdate'
    @table.setDataAtRowProp e.index, 'image', e.value   # update image value in table

  # Method for deleting images on server when Image Modal is closed before confirm
  onVisualizationModalNodeImageDelete: (e) =>
    model = @collection.get e.id
    if model
      # Save model with updated attributes in order to delegate in Collection trigger 'change' events
      model.save {image: null}, {patch: true}

  # Show Add Custom Column Modal handler
  onAddCustomColumn: (e) =>
    e.preventDefault()
    # add custom field to table
    @addCustomColumns [{
      'name': $(e.target).find('#add-custom-column-name').val()
      'type': $(e.target).find('#add-custom-column-type').val()
    }], 'node_custom_fields'
    # re-render table
    @updateTable()
    # clear name input text value
    $('#add-custom-column-name').val('')
    # hide modal
    $('#table-add-column-nodes-modal').modal 'hide'

  # Add Network Analysis result Custom Columns
  addNetworkAnalysisColumns: (visualization, nodes) =>
    # update visualization model !??
    @model.set visualization
    # update nodes collection
    @collection.set nodes
    # add new nodes custom_fields to table
    @addCustomColumns visualization.node_custom_fields, 'node_custom_fields', true
    # update table data & render it
    @table_options.data = @collection.toJSON()
    @table.updateSettings @table_options
    # re-render table
    @updateTable()

  # Override getCustomFieldNameAsLabel in order to translate network analysis names
  getCustomFieldNameAsLabel: (name) ->
    if name == '_cluster' || name == '_degree' || name == '_relevance' || name == '_betweenness' || name == '_closeness' || name == '_coreness'
      lang = if $('body').hasClass('lang-en') then 'en' else 'es'
      name = @network_analysis_names[name][lang]
    else
      name = name.replace(/_+/g, ' ').toLowerCase()
    return name

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
    # Add htVisible class in order to hide checkbox via css
    $(td).addClass 'htVisible'
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
    # Add image icon link
    link = document.createElement('A')
    link.className = if value and value.url then 'icon-image active' else 'icon-image'
    link.innerHTML = link.title = 'Node Image'
    Handsontable.Dom.empty(td)
    td.appendChild(link)
    # Add image modal on click event or keydown (enter or space)
    Handsontable.Dom.addEvent link, 'click', (e) =>
      e.preventDefault()
      @showImageModal row
    return td

module.exports = VisualizationTableNodes
