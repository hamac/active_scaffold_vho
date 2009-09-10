module ActiveScaffold::Config
  class Nested < Base
    self.crud_type = :read

    def initialize(core_config)
      @core = core_config
      self.shallow_delete = self.class.shallow_delete
    end

    # global level configuration
    # --------------------------
    cattr_accessor :shallow_delete
    @@shallow_delete = false

    # instance-level configuration
    # ----------------------------
    attr_accessor :shallow_delete

    # Add a nested ActionLink
    def add_link(label, association, options = {})
      if association.is_a? Array
        ::ActiveSupport::Deprecation.warn("config.nested.add_link with multiple associations is not already supported. The first model will be used", caller)
        association = association.first
      end
      @core.action_links.add('nested', options.merge(:label => label, :type => :record, :security_method => :nested_authorized?, :position => :after, :parameters => {:association => association}, :html_options => {:class => association}))
    end

    # the label for this Nested action. used for the header.
    attr_writer :label
    def label
      @label ? as_(@label) : as_(:add_existing_model, :model => @core.label)
    end

  end
end
