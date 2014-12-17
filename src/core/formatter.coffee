_   = require('lodash')
dom = require('../lib/dom')
OrderedHash = require('../lib/ordered-hash')


class Format
  constructor: (@config) ->

  add: (format, node, value) ->
    return this.remove(node) unless value
    return node if this.value(node) == value
    if _.isString(@config.parentTag)
      parentNode = document.createElement(@config.parentTag)
      dom(node).wrap(parentNode)
      if node.parentNode.tagName == node.parentNode.previousSibling?.tagName
        dom(node.parentNode.previousSibling).merge(node.parentNode)
      if node.parentNode.tagName == node.parentNode.nextSibling?.tagName
        dom(node.parentNode).merge(node.parentNode.nextSibling)
    if _.isString(@config.tag)
      formatNode = document.createElement(@config.tag)
      if dom.VOID_TAGS[formatNode.tagName]?
        dom(node).replace(formatNode) if node.parentNode?
        node = formatNode
      else if @config.type == Formatter.types.LINE
        node = dom(node).switchTag(@config.tag)
      else
        dom(node).wrap(formatNode)
        node = formatNode
    if _.isString(format.style) or _.isString(@config.attribute) or _.isString(@config.class)
      if _.isString(@config.class)
        node = this.remove(node)
      if dom(node).isTextNode()
        inline = document.createElement(dom.DEFAULT_INLINE_TAG)
        dom(node).wrap(inline)
        node = inline
      if _.isString(@config.style)
        node.style[@config.style] = value if value != @config.default
      if _.isString(@config.attribute)
        node.setAttribute(@config.attribute, value)
      if _.isString(@config.class)
        dom(node).addClass(@config.class + value)
    return node

  create: (value) ->

  match: (node) ->
    return false unless dom(node).isElement()
    if _.isString(@config.parentTag) and node.parentNode?.tagName != @config.parentTag
      return false
    if _.isString(@config.tag) and node.tagName != @config.tag
      return false
    if _.isString(@config.style) and (!node.style[@config.style] or node.style[@config.style] == @config.default)
      return false
    if _.isString(@config.attribute) and !node.hasAttribute(@config.attribute)
      return false
    if _.isString(@config.class)
      for c in dom(node).classes()
        return true if c.indexOf(@config.class) == 0
      return false
    return true

  prepare: (value) ->
    if _.isString(@config.prepare)
      document.execCommand(@config.prepare, false, value)
    else if _.isFunction(@config.prepare)
      this.prepare(value)

  remove: (node) ->
    return node unless this.match(node)
    if _.isString(@config.style)
      node.style[@config.style] = ''    # IE10 requires setting to '', other browsers can take null
      node.removeAttribute('style') unless node.getAttribute('style')  # Some browsers leave empty style attribute
    if _.isString(@config.attribute)
      node.removeAttribute(@config.attribute)
    if _.isString(@config.class)
      for c in dom(node).classes()
        dom(node).removeClass(c) if c.indexOf(@config.class) == 0
    if _.isString(@config.tag)
      if @config.type == Formatter.types.LINE
        if _.isString(@config.parentTag)
          dom(node).splitBefore(node.parentNode.parentNode) if node.previousSibling?
          dom(node.nextSibling).splitBefore(node.parentNode.parentNode) if node.nextSibling?
        node = dom(node).switchTag(dom.DEFAULT_BLOCK_TAG)
      else
        node = dom(node).switchTag(dom.DEFAULT_INLINE_TAG)
    if _.isString(@config.parentTag)
      dom(node.parentNode).unwrap()
    if node.tagName == dom.DEFAULT_INLINE_TAG and !node.hasAttributes()
      node = dom(node).unwrap()
    return node

  value: (node) ->
    return undefined unless this.match(node)
    if _.isString(@config.attribute)
      return node.getAttribute(@config.attribute) or undefined    # So "" does not get returned
    else if _.isString(@config.style)
      return node.style[@config.style] or undefined
    else if _.isString(@config.class)
      for c in dom(node).classes()
        return c.slice(@config.class.length) if c.indexOf(@config.class) == 0
    else if _.isString(@config.tag)
      return true
    return undefined


class Formatter extends OrderedHash
  @formats: new OrderedHash()

  @types:
    EMBED: 'embed'
    LINE: 'line'

  @Format: Format

  add: (name) ->
    format = Formatter.formats.get(name)
    throw new Error("Cannot load #{name} format. Are you sure you registered it?") unless format?
    this.set(name, format)
    # TODO Suboptimal performance and somewhat hacky
    @keys.sort(_.bind(Formatter.formats.compare, Formatter.formats))

  check: (node) ->
    # TODO optimize
    return _.reduce(@hash, (formats, format, name) ->
      if value = format.value(node)
        formats[name] = value
      return formats
    , {})


module.exports = Formatter