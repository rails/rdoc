require 'rdoc/code_object'
require 'rdoc/tokenstream'

##
# AnyMethod is the base class for objects representing methods

class RDoc::AnyMethod < RDoc::CodeObject

  MARSHAL_VERSION = 0

  include Comparable

  ##
  # Method name

  attr_writer :name

  ##
  # public, protected, private

  attr_accessor :visibility

  ##
  # Parameters yielded by the called block

  attr_accessor :block_params

  ##
  # Don't rename \#initialize to \::new

  attr_accessor :dont_rename_initialize

  ##
  # Is this a singleton method?

  attr_accessor :singleton

  ##
  # Source file token stream

  attr_reader :text

  ##
  # Array of other names for this method

  attr_reader :aliases

  ##
  # Fragment reference for this method

  attr_reader :aref

  ##
  # The method we're aliasing

  attr_accessor :is_alias_for

  ##
  # Parameters for this method

  attr_overridable :params, :param, :parameters, :parameter

  ##
  # Different ways to call this method

  attr_accessor :call_seq

  include RDoc::TokenStream

  ##
  # Resets method fragment reference counter

  def self.reset
    @@aref = 'M000000'
  end

  reset

  def initialize(text, name)
    super()
    @text = text
    @name = name
    @token_stream  = nil
    @visibility    = :public
    @dont_rename_initialize = false
    @block_params  = nil
    @aliases       = []
    @is_alias_for  = nil
    @call_seq      = nil
    @singleton     = nil

    @aref  = @@aref
    @@aref = @@aref.succ
  end

  ##
  # Order by #singleton then #name

  def <=>(other)
    [@singleton ? 0 : 1, @name] <=> [other.singleton ? 0 : 1, other.name]
  end

  ##
  # Adds +method+ as an alias for this method

  def add_alias(method)
    @aliases << method
  end

  ##
  # HTML id-friendly method name

  def html_name
    @name.gsub(/[^a-z]+/, '-')
  end

  def inspect # :nodoc:
    alias_for = @is_alias_for ? " (alias for #{@is_alias_for.name})" : nil
    "#<%s:0x%x %s (%s)%s>" % [
      self.class, object_id,
      full_name,
      visibility,
      alias_for,
    ]
  end

  ##
  # Full method name including namespace

  def full_name
    @full_name ||= "#{@parent ? @parent.full_name : '(unknown)'}#{pretty_name}"
  end

  def marshal_dump
    aliases = @aliases.map do |a|
      [a.full_name, parse(a.comment)]
    end

    [ MARSHAL_VERSION,
      @name,
      full_name,
      @singleton,
      @visibility,
      parse(@comment),
      @call_seq,
      @block_params,
      aliases,
    ]
  end

  def marshal_load(array)
    @name         = array[1]
    @full_name    = array[2]
    @singleton    = array[3]
    @visibility   = array[4]
    @comment      = array[5]
    @call_seq     = array[6]
    @block_params = array[7]

    array[8].each do |old_name, new_name, comment|
      add_alias RDoc::Alias.new(nil, old_name, new_name, comment)
    end
  end

  ##
  # Method name

  def name
    return @name if @name

    @name = @call_seq[/^.*?\.(\w+)/, 1] || @call_seq
  end

  ##
  # Pretty parameter list for this method

  def param_seq
    params = params.gsub(/\s*\#.*/, '')
    params = params.tr("\n", " ").squeeze(" ")
    params = "(#{params})" unless p[0] == ?(

    if block = block_params then # yes, =
      # If this method has explicit block parameters, remove any explicit
      # &block
      params.sub!(/,?\s*&\w+/)

      block.gsub!(/\s*\#.*/, '')
      block = block.tr("\n", " ").squeeze(" ")
      if block[0] == ?(
        block.sub!(/^\(/, '').sub!(/\)/, '')
      end
      params << " { |#{block}| ... }"
    end

    params
  end

  ##
  # Path to this method

  def path
    "#{@parent.path}##{@aref}"
  end

  ##
  # Method name with class/instance indicator

  def pretty_name
    "#{singleton ? '::' : '#'}#{@name}"
  end

  def pretty_print q # :nodoc:
    alias_for = @is_alias_for ? "alias for #{@is_alias_for.name}" : nil

    q.group 2, "[#{self.class.name} #{full_name}", "]" do
      q.text alias_for if alias_for

      if text then
        q.text "text:"
        q.breakable
        q.pp @text
      end

      unless comment.empty? then
        q.text "comment:"
        q.breakable
        q.pp @comment
      end
    end
  end

  def to_s # :nodoc:
    "#{self.class.name}: #{full_name} (#{@text})\n#{@comment}"
  end

  ##
  # Type of method (class or instance)

  def type
    singleton ? 'class' : 'instance'
  end

end

