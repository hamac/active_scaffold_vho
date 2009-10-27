module ActiveScaffold::Actions
  module Core
    def self.included(base)
      base.class_eval do
        after_filter :clear_flashes
        helper_method :parent_controller
      end
    end
    def render_field
      @record = active_scaffold_config.model.new
      column = active_scaffold_config.columns[params[:column]]
      value = if column.association
        params[:value].blank? ? nil : column.association.klass.find(params[:value])
      else
        params[:value]
      end
      @record.send "#{column.name}=", value
      @update_column = active_scaffold_config.columns[column.options[:update_column]]
    end

    protected

    def authorized_for?(*args)
      active_scaffold_config.model.authorized_for?(*args)
    end

    def clear_flashes
      if request.xhr?
        flash.keys.each do |flash_key|
          flash[flash_key] = nil
        end
      end
    end

    def default_formats
      [:html, :js, :json, :xml, :yaml]
    end
    # Returns true if the client accepts one of the MIME types passed to it
    # ex: accepts? :html, :xml
    def accepts?(*types)
      for priority in request.accepts.compact
        if priority == Mime::ALL
          # Because IE always sends */* in the accepts header and we assume
          # that if you really wanted XML or something else you would say so
          # explicitly, we will assume */* to only ask for :html
          return types.include?(:html)
        elsif types.include?(priority.to_sym)
          return true
        end
      end
      false
    end

    def response_status
      successful? ? 200 : 500
    end

    # API response object that will be converted to XML/YAML/JSON using to_xxx
    def response_object
      @response_object = successful? ? (@record || @records) : @record.errors
    end

    # Success is the existence of certain variables and the absence of errors (when applicable).
    # Success can also be defined.
    def successful?
      if @successful.nil?
        @records or (@record and @record.errors.count == 0 and @record.no_errors_in_associated?)
      else
        @successful
      end
    end

    def successful=(val)
      @successful = (val) ? true : false
    end

    # Redirect to the main page (override if the ActiveScaffold is used as a component on another controllers page) for Javascript degradation
    def return_to_main
      params[:controller] = parent_controller unless @parent_class_for_inline_form.nil?
      redirect_to params_for(:action => "index", :id => nil)
    end

    # Override this method on your controller to define conditions to be used when querying a recordset (e.g. for List). The return of this method should be any format compatible with the :conditions clause of ActiveRecord::Base's find.
    def conditions_for_collection
    end
  
    # Override this method on your controller to define joins to be used when querying a recordset (e.g. for List).  The return of this method should be any format compatible with the :joins clause of ActiveRecord::Base's find.
    def joins_for_collection
    end
  
    # Override this method on your controller to provide custom finder options to the find() call. The return of this method should be a hash.
    def custom_finder_options
      {}
    end

    def parent_controller
      self.class.active_scaffold_controller_for(@parent_class_for_inline_form).controller_path if @parent_class_for_inline_form
    end

    # Builds search conditions by search params for column names. This allows urls like "contacts/list?company_id=5".
    def conditions_from_params
      conditions = nil
      params.reject {|key, value| [:controller, :action, :id, :page, :sort, :sort_direction].include?(key.to_sym)}.each do |key, value|
        next unless active_scaffold_config.model.column_names.include?(key)
        if value.is_a?(Array)
          conditions = merge_conditions(conditions, ["#{active_scaffold_config.model.table_name}.#{key.to_s} in (?)", value])
        else
          conditions = merge_conditions(conditions, ["#{active_scaffold_config.model.table_name}.#{key.to_s} = ?", value])
        end
      end
      conditions
    end
    private
    def respond_to_action(action)
      respond_to do |type|
        send("#{action}_formats").each do |format|
          type.send(format){ send("#{action}_respond_to_#{format}") }
        end
      end
    end

    def response_code_for_rescue(exception)
      case exception
        when ActiveScaffold::RecordNotAllowed
          "403 Record Not Allowed"
        when ActiveScaffold::ActionNotAllowed
          "403 Action Not Allowed"
        else
          super
      end
    end

    def is_inline_form
      active_scaffold_constraints.any? do |key, value|
        column = active_scaffold_config.columns[key]
        if column.polymorphic_association?
          value.class.reflect_on_all_associations.any? do |assoc|
            key == assoc.options[:as] && active_scaffold_config.model.name == assoc.class_name && [:has_one, :belongs_to].include?(assoc.macro)
          end and @parent_class_for_inline_form = value.class
        else
          reverse_macro = column.association.klass.reflect_on_association(column.association.reverse).try(:macro)
          @parent_class_for_inline_form = column.association.klass if [:has_one, :belongs_to].include? reverse_macro
        end
      end
    end
  end
end
