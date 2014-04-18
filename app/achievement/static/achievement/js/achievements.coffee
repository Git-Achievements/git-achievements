###
 * TODO: Finish the transition to exoskeleton.js
###


RegExp.escape = (s) ->
    # Escapes a string passed to it for consumption by
    # a Regexp constructor.
    # Reference: //stackoverflow.com/questions/3561493
    s.replace /[-\/\\^$*+?.()|[\]{}]/g, '\\$&'


String.prototype.format = () ->
    # Formats a string using {i} as a selector, similar to Python's
    # .format method.
    string = @
    replacements = Array.prototype.slice.call(arguments, 0)

    for i in [0..replacements.length - 1] by 1
        pattern = new RegExp(RegExp.escape("\{#{i}\}"), 'g')
        string = string.replace(pattern, replacements[i])

    string


String.prototype.template = (keywords) ->
    # Renders a template using syntax of <%= key %> as a
    # placeholder for where they value should be put
    string = @

    for key of keywords
        value = keywords[key]
        pattern = new RegExp("<%=\\s*#{key}\\s*%>", 'gi')
        string = string.replace(pattern, value)

    string.replace(/<\/?script>/g, '')


String.prototype.toTitleCase = () ->
    # Formats a string in titlecase
    string = @
    peices = string.split(" ")

    for i in [0..peices.length - 1] by 1
        peices[i] = peices[i][0].toUpperCase() + peices[i].substr(1)

    peices.join " "


String.prototype.trim = () ->
    # Fallback for browsers that don't support the trim() method
    # *cough* IE8 *cough* why are you using it *cough*
    @replace /^\s+|\s+$/gm, ''


# The API root for the application
API_ROOT = '/api/v1/{0}/'


class Application extends Object
    API_ROOT: API_ROOT

    constructor: (options) ->
        @$ = (window.$ || window.jQuery)

    getCookie: (name) ->
        cookieValue = null
        if document.cookie and document.cookie != ''
            cookies = document.cookie.split ';'
            for cookie in cookies
                cookie = cookie.trim()
                if cookie.substring(0, name.length + 1) == name + '='
                    cookieValue = decodeURIComponent(cookie.substring(name.length + 1))
                    break
        cookieValue

    csrfSafeMethod: (method) ->
        # Methods that don't require CSRF protection
        /^(GET|HEAD|OPTIONS|TRACE)$/.test method

    sameOrigin: (url) ->
        # Test that a url is a same-origin url
        host = document.location.host
        protocol = document.location.protocol
        sr_origin = "//#{host}"
        origin = "#{protocol}#{sr_origin}"

        return (url == origin || url.slice(0, origin.length + 1) == origin + '/') ||
            (url == sr_origin || url.slice(0, sr_origin.length + 1) == sr_origin + '/') ||
            !(/^(\/\/|http:|https:).*/.test(url))

    setupAjax: () ->
        # Set up CSRF token for Ajax requests
        self = @
        csrftoken = @getCookie 'csrftoken'
        $.ajax
            beforeSend: (xhr, settings) ->
                if (!self.csrfSafeMethod(settings.type) && self.sameOrigin(settings.url))
                    # Send the token to same-origin, relative URLs only
                    # Send the token iff method warrants CSRF protection
                    # Use the CSRFToken value acquired earlier
                    xhr.setRequestHeader 'X-CSRFToken', csrftoken

    formatQueryStrings: (querystrings) ->
        # Encodes a dictionary of key-value pairs into query parameters
        query = ''
        for key, value of querystrings
            query += "#{key}=#{value}&"

        encodeURIComponent query

    fetch: (endpoint, querystrings, async) ->
        # Fetches data from the specified API endpoint either asynchronously
        # or synchronously.
        opts = {
            url: @API_ROOT.format(endpoint) + '?' + @formatQueryStrings(querystrings || {}),
            async: async,
            dataType: "json"
        }
        result = undefined

        if async == false and async != undefined
            $.ajax(opts).done (data) ->
                result = data
        else
            result = $.ajax(opts)

        result

    debugEnabled: () ->
        debug = parseInt @getQueryStringValue('debug'), 10
        debug > 0

    getQueryStringValue: (query) ->
        pattern = new RegExp("[\\?&]#{query}=([^&#]*)")
        results = pattern.exec(location.search)
        if results
            decodeURIComponent(results[1].replace(/\+/g, ' '))
        else
            ''

    addForm: (name, target) ->
        # Renders and adds the specified form the page
        name = name.toTitleCase()
        target = $(target || 'body').eq(0)
        form = new @Views["#{name}Form"]({
            'el': "form"
        })
        target.append(form.render().$el)
        @

    shuffle: (array) ->
        # Performs a FisherYates shuffle on an array and returns a new array
        # that has been randomized
        array = array.slice(0)
        index = 0
        currentIndex = array.length

        while currentIndex > 0
            index = Math.floor(Math.random() * currentIndex)
            currentIndex -= 1
            tmp = array[currentIndex]
            array[currentIndex] = array[index]
            array[index] = tmp

        array

    uniqueId: () ->
        # Generates a unique id by randomizing an array and concatenating from that
        # array a set of characters
        characters = 'abcdefghijklmnopqrstuvwxyz'.split(' ').concat('0123456789'.split(' '))
        id = null
        maxlen = 10

        while id == null || $('#' + id).length
            id = @shuffle(characters).slice(0, maxlen)

        id.join("")


###
# Placeholder for Views and Models
###
Application = new Application()
Application.Views = {}
Application.Models = {}


###
# Application Models
####
class Application.Models.Event extends Backbone.Model
    # Represents an event/payload combination supported by the Application
    initialize: (opts) ->
        @name = opts.name
        @type = opts.id
        attributes = {}
        stack = []
        stack.push
            name: "",
            attributes: opts.attributes

        while stack.length > 0
            # Until we've exhausted the stack, assume whatever is ont he top of
            # the stack is an object.
            item = stack.shift()
            name = item.name

            for key, value of item.attributes
                # If we've reached a value that is a string, it means taht the current key,
                # we've reached an attribute
                if typeof value == 'string'
                    key = if name.length then "#{name}.#{key}" else key
                    attributes[key] = value
                else
                    stack.push
                        name: if name.length then "#{name}.#{key}" else key,
                        attributes: if $.isArray(value) then value[0] else value

        @set('event-attributes', attributes)

    getAttributes: (type) ->
        # Gets the different attributes that exist for that event, optionally
        # filtered by the expected argument type
        eventData = @get('event-attributes')
        if type
            tmp = {}
            $.each eventData, (key, value) ->
                if value == type
                    tmp[key] = value
            eventData = tmp
        $.map eventData, ((value, key) ->
            attribute: key
            type: value
        )

    getJSON: () ->
        # We just need the event's attribute
        @model.get 'event-attribute'


class Application.Models.EventCollection extends Backbone.Collection
    # A collection of events that the Application supports
    url: API_ROOT.format('event')
    model: Application.Models.Event

    parse: (response) ->
        response.objects || []


class Application.Models.Method extends Backbone.Model
    # Different methods supported by the application, should be typechecked by the view
    # to ensure the attribute and method types match
    type: () ->
        @get('argument_type')

    getJSON: () ->
        # Since we can't create methods in forms, the "json" of a
        # method is just it's id.
        @get 'id'


class Application.Models.MethodCollection extends Backbone.Collection
    # Collection of methods/functions
    url: API_ROOT.format('method')
    model: Application.Models.Method

    parse: (response) ->
        response.objects || []


class Application.Models.Difficulty extends Backbone.Model
    getJSON: () ->
        @get 'id'


class Application.Models.DifficultyCollection extends Backbone.Collection
    url: API_ROOT.format('difficulty')
    model: Application.Models.Difficulty

    parse: (response) ->
        response.objects || []


class Application.Models.AchievementType extends Backbone.Model
    getJSON: () ->
        @get 'id'


class Application.Models.AchievementTypeCollection extends Backbone.Collection
    url: API_ROOT.format('achievementtype')
    model: Application.Models.AchievementType

    parse: (response) ->
        response.objects || []


class Application.Models.Condition extends Backbone.Model
    # Represents a generic condition, this class does not know what type of condiition
    # it represents, it's up for the callee to determine
    initialize: (opts) ->
        @set 'name', @get('description')

    getJSON: () ->
        $.extend true, {}, @attributes


class Application.Models.ConditionCollection extends Backbone.Collection
    # Collection of conditions; mostly used for custom conditions, may
    # be extended eventually for noral conditions
    url: API_ROOT.format('customcondition')
    model: Application.Models.Condition

    parse: (response) ->
        response.objects || []


class Application.Models.Badge extends Backbone.Model
    # Represents a Badge object
    getJSON: () ->
        name: @get('name'),
        description: @get('description')


###
# Application Views
###
class Application.Views.EventAttributeSelect extends Backbone.View
    # A EventAttributeSelect is a select of the various Event attributes
    # belonging to an event
    el: 'select'
    className: ''
    events:
        'change': "onChange"

    onChange: () ->
        selected = @$el.find('option:selected')
        @trigger 'change',
            attribute: selected.val()
            type: selected.data('type')

    render: () ->
        # render, we add the attributes to the select box and initialize
        # the selectit box
        @$el = $(document.createElement(@tagName))
        for className in @className.split(' ')
            @$el.addClass(className)

        if @template
            @$el.html(@template.template(@model.attributes))
        else
            @$el.html()
        @$el.attr('id', @model.cid)
        @filter()

    filter: (type) ->
        # Apply the filter, if one exists, to determine whic attributes can
        # be shown
        $el = @$el
        event_name = @model.get('name').replace(/\._/g, " ").toTitleCase()
        $.each @model.getAttributes(type), (attribute) ->
            name = attribute.attribute.replace(/\./g, "'s ").replace(/_/g, " ")
            option = $('<opton></option>')
                .attr('value', attribute.attribute)
                .data('type', attribute.type)
                .text("#{event_name}'s #{name}")
            $el.append option
        @$el.select2('destroy')
        @$el.select2()
        @


class Application.Views.DifficultySelect extends Backbone.View
    # Displays a sleect for a Difficulty collection, does not require a
    # template as it displays as a select
    tagName: 'select'
    events:
        'change': "onChange"

    initialize: (opts) ->
        @collection = new Application.Models.DifficultyCollection()
        @model = @collection

    onChange: (ev) ->
        selected = @$el.find('option:selected')
        model = @collection.get selected.val()
        @trigger 'change', model

    render: () ->
        # The model for this is actually a collection
        @$el = $(document.createElement(@tagName))
        self = @
        @collection.fetch().done () ->
            for model in self.collection.models
                option = $('<option></option>')
                option.val(model.cid)
                option.text(model.get('name').toTitleCase())
                self.$el.append(option)

            self.$el
                .attr('id', Application.uniqueId())
                .select2()

        @


class Application.Views.MethodSelect extends Application.Views.DifficultySelect
    # Displays a select of methods
    initialize: (opts) ->
        @collection = new Application.Models.MethodCollection()
        @model = @collection

    filter: (type) ->
        @$el.select2('destroy')
        @$el.children().remove()
        for model in @collection.models
            if type and model.get('type') != type
                continue
            option = $('<option></option>')
            option.val(model.cid)
            option.text(model.get('name').toTitleCase())
            @$el.append(option)

        @$el.select2()
        @
       

class Application.Views.AchievementTypeSelect extends Application.Views.DifficultySelect
    # Essentially the same as a DifficultySelect excepts uses a different collection
    # and triggers a different thing
    initialize: (opts) ->
        @collection = new Application.Models.AchievementTypeCollection()
        @model = @collection


class Application.Views.ConditionSelect extends Application.Views.DifficultySelect
    # Displays a select of conditions
    initialize: (opts) ->
        @collection = new Application.Models.ConditionCollection()
        @model = @collection


class Application.Views.BadgeForm extends Backbone.View
    # Subform for creating a badge
    tagName: 'fieldset'
    template: '#badge-form'
    className: 'rounded-box'
    events:
        'change input': "onChange"
        'keyup textarea': "onChange"
        'paste textarea': "onChange"
        'change textarea': "onChange"

    initialize: () ->
        @model.set('id', @model.cid)

    # TODO: Add a badge preview option
    onChange: (ev) ->
        target = @$(ev.currentTarget)
        name = target.attr('name')

        if target.is('textarea')
            @model.set(name, target.text())
        else
            @model.set(name, target.val())

    serialize: () ->
        @model.getJSON()


class Application.Views.CustomConditionForm extends Backbone.View
    # A custom condition for simply has a selection that the user must choose
    # This is essentially a layout
    tagName: 'fieldset'
    template: '#custom-condition-form'
    className: 'rounded-box'
    regions:
        'condition': null

    render: () ->
        @$el = $(document.createElement(@tagName))
        for className in @className.split(' ')
            @$el.addClass(className)

        @$el.html($(@template).html().template({'id': @id}))
        selector = if regions.condition then @$(regions.condition) else @$el

        @regions.condition = new Application.Views.ConditionSelect()
        @listenTo(@regions.condition, 'change', @conditionChange)
        selector.append(regions.condition.render().$el)
        @

    conditionChange: (model) ->
        @data ?= {}
        @data.condition = model.get('id')

    serialize: () ->
        id: @data.condition


class Application.Views.ValueConditionForm extends Backbone.View
    # Subform for creating a value condition.  Has select for event attributes,
    # methods, and input for a value.
    tagName: 'fieldset'
    template: '#value-condition-form'
    className: 'rounded-box'
    regions:
        'attribute': ".condition-attribute"
        'value': ".condition-value"
        'method': ".condition-method"
        'description': ".condition-description"

    initialize: () ->
        @data = {}

    render: () ->
        self = @
        @$el = $(document.createElement(@tagName))
        for className in @className.split(' ')
            @$el.addClass(className)

        @$el.html($(@template).html().template(@model.attributes))

        # Render the subviews using the selected specified by the regions
        view = new Application.Views.EventAttributeSelect(@model)
        @$(@regions.attribute).append(view.render().$el)
        @regions.attribute = view
        @listenTo view, 'change', (attribute) ->
            self.data.attribute = attribute.attribute
            self.regions.method.filter(attribute.type)

        view = new Application.Views.MethodSelect()
        @$(@regions.method).append(view.render().$el)
        @regions.method = view
        @listenTo view, 'change', (method) ->
            self.data.method = method.get('id')
            self.regions.attribute.filter(method.get('argument_type'))

        # We need to create two input objects to accept the description (name)
        # of the condition and the value it expects
        view = $('<input></input>')
        @$(@regions.value).append(view)
        @regions.value = view

        view = $('<input></input>')
        @$(@regions.description).append(view)
        @regions.description = view

        @

    serialize: () ->
        $.extend true, {},
            method: self.data.method
            attribute: self.data.attribute
            value: @regions.value.val()
            event_type: @model.get('event_type')
            description: @regions.description.val()


class Application.Views.AchievementForm extends Backbone.View
    # The main form used to create an achievement by adding together the subforms
    # for a badge, custom condition, value condition, and attribute condition
    tagName: 'form'
    template: '#achievement-form'
    className: ''
    post: "/achievements/create"
    method: "POST"

    regions:
        'conditions': "#conditions"
        'badge': "#badge"
        'type': "#type"
        'description': "#description"
        'name': "#name"
        'difficulty': "#difficulty"
        'grouping': "#grouping"

    events:
        'click .js-add-condition': "addCondition"
        'click .js-add-badge': "addBadge"

    initialize: (opts) ->
        @data = {}

    addBadge: () ->
        if not @data.badge
            @data.badge = new Application.Views.BadgeForm()
            @regions.badge.append(@data.badge.render().$el)
            # We listen to the remove event on the badge view, so that
            # we can remove it from the data
            @listenTo @data.badge, 'remove', @addBadge
        else
            @data.badge = null

    addCondition: (ev) ->
        form = undefined
        target = $(ev.currentTarget)
        name = target.data('condition')
        newId = @regions.conditions.length + 1

        if name == 'custom'
            @data['custom-conditions'] ?= []
            form = new Application.Views.CustomConditionForm({'id': newId})
            @data['custom-conditions'].push(form)
        else if name == 'value'
            @data['value-conditions'] ?= []
            form = new Application.Views.ValueConditionForm({'id': newId})
            @data['value-conditions'].push(form)
        else
            console.warn 'getConditionType called with unknown condition'

        if form != undefined
            @regions.conditions.append(condition.render().$el)

    render: () ->
        # Render the form, the select it boxes, and the subform into the
        # DOM
        self = @
        @$el = $(document.createElement(@tagName))
        for className in @className.split(' ')
            @$el.addClass(className)

        @$el.html($(@template).html().template())
        @$el.attr('method', @method)
            .attr('post', @post)

        # Turn the regions into jQuery selectors
        @regions.badge = @$(@regions.badge)
        @regions.conditions = @$(@regions.conditions)
        @regions.name = @$(@regions.name)
        @regions.description = @$(@regions.description)
        @regions.grouping = @$(@regions.grouping)

        # Render the subviews into their regions
        select = new Application.Views.AchievementTypeSelect()
        $el = select.render().$el
        region = @$(@regions.type)
        $el
            .css('width', "300px")
            .attr('name', region.attr('name'))
            .attr('id', region.attr('id'))
        region.replaceWith($el)
        @listenTo select, 'change', (model) ->
            self.data.achievement ?= {}
            self.data.achievement.type = model.get('id')

        select = new Application.Views.DifficultySelect()
        $el = select.render().$el
        region = @$(@regions.difficulty)
        $el
            .css('width', "300px")
            .attr('name', region.attr('name'))
            .attr('id', region.attr('id'))
        region.replaceWith($el)
        @listenTo select, 'change', (model) ->
            self.data.achievement ?= {}
            self.data.achievement.difficulty = model.get('id')

        @regions.grouping.select2()
        @

    serialize: () ->
        # Return all the data from the subforms serialized as a JSON
        # object.
        data = $.extend true, {}, @data
        data.achievement = $.extend true, data.achivement,
            name: @regions.name.val()
            description: @regions.description.val()
            grouping: @regions.grouping.val()

        if data.badge
            data.badge = data.badge.serialize()

        for condition in ['custom-conditions', 'value-conditions']
            if data[condition]
                # Map each condition to the serialized data
                data[condition] = $.map data[condition], (form) ->
                    form.serialize()

        data


do (window, $ = window.$ || window.jQuery, Backbone = window.Backbone) ->
    window.App = Application
    console.log '%cGit Achievements', "color: #666; font-size: x-large; font-family 'Comic Sans', serif;"
    console.log '\u00A9 Ford Peprah, 2013-2014'
