class CrudController < ApplicationController
  before_filter :setup, except: :autocomplete

  def index
    authorize! :read, @model_permission if respond_to?(:current_usuario)
    if params[:scope].present? && valid_method?(params[:scope])
      @q = @model.send(params[:scope]).search(params[:q])
    else
      @q = @model.search(params[:q])
    end

    if @q.sorts.empty?
      if @crud_helper.order_field.to_s.include?("desc") || @crud_helper.order_field.to_s.include?("asc")
        @q.sorts = @crud_helper.order_field.to_s
      else
        @q.sorts = "#{@crud_helper.order_field} asc"
      end
    end

    if respond_to?(:current_usuario)
      @records = @q.result.accessible_by(current_ability, :read).uniq.page(params[:page]).per(@crud_helper.per_page)
    else
      @records = @q.result.uniq.page(params[:page]).per(@crud_helper.per_page)
    end

    if (relations = @crud_helper.index_includes).present?
      @records = @records.includes(*relations)
    end

    @titulo = @model.name.pluralize
    render partial: 'records' if request.respond_to?(:wiselinks_partial?) && request.wiselinks_partial?
  end

  def new
    if params[:render] == "modal"
      if @model.reflect_on_association(params[:attribute].to_s).present?
        @model = @model.reflect_on_association(params[:attribute].to_s).class_name.constantize
      else
        @model = params[:attribute].to_s.camelcase.constantize
      end
      @url = crud_models_path(model: @model.name.underscore)
      @clean_url = @url
      @model_permission = @model
      @crud_helper = Module.const_get("#{@model}Crud".camelize)
    end
    authorize! :new, @model_permission if respond_to?(:current_usuario)
    @record = @model.new
  end

  def edit
    @record = @model.find(@id)
    authorize! :edit, @record if respond_to?(:current_usuario)
  end

  def show
    @record = @model.find(@id)
    authorize! :read, @record if respond_to?(:current_usuario)
  end

  def action
    @record = @model.find(@id)
    authorize! :create_or_update, @record if respond_to?(:current_usuario)
    if valid_instance_method?(params[:acao])
      if @record.send(params[:acao])
        flash.now[:success] = I18n.t("mensagem_action", acao: params[:acao])
      else
        flash.now[:error] = I18n.t("mensagem_erro_action", acao: params[:acao])
      end
      redirect_to @url
    else
      @titulo = @record.to_s
      @texto = params[:acao]
      render partial: "/#{@model.name.underscore.pluralize}/#{params[:acao]}" if request.respond_to?(:wiselinks_partial?) && request.wiselinks_partial?
    end
  end

  def create
    @saved = false
    if @id
      @record = @model.find(@id)
      authorize! :update, @record if respond_to?(:current_usuario)
      @saved = @record.update(params_permitt)
    else
      @record  =  @model.new(params_permitt)
      authorize! :create, @model_permission if respond_to?(:current_usuario)
      @saved = @record.save
    end

    respond_to do |format|
      if @saved
        flash[:success] = params[:id].present? ? I18n.t("updated", model: I18n.t("model.#{@model.name.underscore}")) : I18n.t("created", model: I18n.t("model.#{@model.name.underscore}"))
        format.html { redirect_to @url }
        unless params[:render] == 'modal'
          format.js { render action: :index}
        else
          format.js
        end
      else
        action = (params[:id]) ? :edit : :new
        format.html { render action: action }
        format.js
      end
    end
  end

  def destroy
    @record = @model.find(@id)
    authorize! :destroy, @record if respond_to?(:current_usuario)
    if @record.destroy
      respond_to do |format|
        flash[:success] = I18n.t("destroyed", model: I18n.t("model.#{@model.name.underscore}"))
        format.html { redirect_to @url }
        format.js { render action: :index }
      end
    else
      respond_to do |format|
        flash[:error] = @record.errors.full_messages.join(", ")
        format.html { redirect_to @url }
        format.js { render action: :index }
      end
    end
  end

  def query
    authorize! :read, @model_permission if respond_to?(:current_usuario)
    @resource = @model
    if params[:scope].present? && valid_method?(params[:scope])
      @q = @model.send(params[:scope]).search(params[:q])
    else
      @q = @model.search(params[:q])
    end
    @q.sorts = 'updated_at desc' if @q.sorts.empty?

    if respond_to?(:current_usuario)
      results = @q.result.accessible_by(current_ability).uniq.page(params[:page])
    else
      results = @q.result.uniq.page(params[:page])
    end

    if (relations = @crud_helper.index_includes).present?
      results = results.includes(*relations)
    end

    instance_variable_set("@#{params[:var]}", results)
    if request.respond_to?(:wiselinks_partial?) && request.wiselinks_partial?
      render :partial => params[:partial]
    else
      render :index, controller: request[:controller]
    end
  end

  def autocomplete
    @model = Module.const_get(params[:model].camelize)
    authorize! :read, @model if respond_to?(:current_usuario)
    parametros = {}
    parametros["#{params[:campo]}_#{params[:tipo]}"] = params[:term]
    @q = @model.search(parametros)
    @q.sorts = 'updated_at desc' if @q.sorts.empty?
    if respond_to?(:current_usuario)
      results = @q.result.accessible_by(current_ability).uniq.page(params[:page])
    else
      results = @q.result.uniq.page(params[:page])
    end
    if valid_instance_method?(params[:label])
      method_label = params[:label]
    else
      raise "Ação inválida"
    end
    render json: results.map {|result| {id: result.id, label: result.send(method_label), value: result.send(method_label)} }
  end

  def listing
    authorize! :read, @model_permission if respond_to?(:current_usuario)
    if params[:scope].present? && valid_method?(params[:scope])
      @q = @model.send(params[:scope]).search(params[:q])
    else
      @q = @model.search(params[:q])
    end

    if @q.sorts.empty?
      if @crud_helper.order_field.to_s.include?("desc") || @crud_helper.order_field.to_s.include?("asc")
        @q.sorts = @crud_helper.order_field.to_s
      else
        @q.sorts = "#{@crud_helper.order_field} asc"
      end
    end

    if respond_to?(:current_usuario)
      @records = @q.result.uniq.accessible_by(current_ability)
    else
      @records = @q.result.uniq
    end
    report_name = "#{@crud_helper.title}_#{DateTime.now.strftime('%Y%m%d')}"
    respond_to do |format|
      format.xls { headers["Content-Disposition"] = "attachment; filename=#{report_name}.xls" }
      format.pdf do
        pdf = generate_pdf_report(@crud_helper.setup_report_listing, 'crud/listing.pdf.erb')
        send_data(pdf, filename: "#{report_name}.pdf", type: "application/pdf", disposition: "inline")
      end
    end
  end

  def printing
    @record = @model.find(@id)
    authorize! :read, @record if respond_to?(:current_usuario)
    report_name = "#{@record}_#{DateTime.now.strftime('%Y%m%d')}"
    respond_to do |format|
      format.pdf do
        pdf = generate_pdf_report(@crud_helper.setup_report_printing, 'crud/printing.pdf.erb')
        send_data(pdf, filename: "#{report_name}.pdf", type: "application/pdf", disposition: "inline")
      end
      format.html
    end
  end

  private
  def generate_pdf_report(opts, layout)
    html = render_to_string(layout)
    options = {
      encoding: 'UTF-8',
      orientation: opts[:orientation],
      page_size: 'A4',
      show_as_html: params[:debug],
      margin: { top: opts[:top], bottom: opts[:bottom] }
    }
    if opts[:header].present?
      options[:header] = {content: render_to_string(template: opts[:header], locals: {title: @crud_helper.title})}
    end
    if opts[:footer].present?
      options[:footer] = {content: render_to_string(template: opts[:footer])}
    end
    WickedPdf.new.pdf_from_string(html, options)
  end

  def setup
    if params[:associacao]
      @crud_associacao = Module.const_get("#{params[:model].to_s.singularize}_crud".camelize)
      if Module.const_get(params[:model].camelize).reflect_on_association(params[:associacao])
        @model = Module.const_get(params[:model].camelize).find(params[:id]).send(params[:associacao])
      else
        raise "Ação inválida"
      end
      c_helper = Module.const_get(params[:model].camelize).reflect_on_association(params[:associacao]).class_name
      @crud_helper = Module.const_get("#{c_helper}Crud") unless params[:render] == "modal" and params[:action] == "new"
      @url = crud_associacao_models_path(model: params[:model], id: params[:id], associacao: params[:associacao], page: params[:page], q: params[:q])
      @clean_url = crud_associacao_models_path(model: params[:model], id: params[:id], associacao: params[:associacao])
      @model_permission = c_helper.constantize
      @id = params[:associacao_id] if params[:associacao_id]
    else
      @model = Module.const_get(params[:model].camelize)
      @model_permission = @model
      @crud_helper = Module.const_get("#{params[:model]}_crud".camelize) unless params[:render] == "modal" and params[:action] == "new"
      @url = crud_models_path(model: params[:model], page: params[:page], q: params[:q])
      @clean_url = crud_models_path(model: params[:model])
      @id = params[:id] if params[:id]
    end
  end

  def params_permitt
    params.require(@model.name.underscore.gsub('/','_').to_sym).permit(fields_model)
  end

  def fields_model
    fields = []
    @crud_helper.form_fields.each do |field|
      if field[:sf].present? && field[:sf][:grupo].present?
        fields << permitt_group(fields, field[:attribute], field[:sf][:fields],@model)
      else
        if @model.reflect_on_association(field[:attribute])
          if @model.reflect_on_association(field[:attribute]).macro == :belongs_to
            fields << @model.reflect_on_association(field[:attribute]).foreign_key
          else
            fields << {"#{field[:attribute].to_s.singularize}_ids".to_sym => []}
          end
        elsif @model.columns_hash[field[:attribute].to_s]
          if @model.columns_hash[field[:attribute].to_s].cast_type.class == ActiveRecord::Type::Serialized
            fields << {field[:attribute] => []}
          else
            fields << field[:attribute]
          end
        end
      end
    end
    #TODO - Deprecated
    @crud_helper.form_groups.each do |key, groups|
      fields << permitt_group(fields, key, groups[:fields],@model)
    end
    #Fim - Deprecated
    if @model.respond_to?(:params_permitt)
      @model.params_permitt.each do |field|
        fields << field
      end
    end
    fields
  end

  def permitt_group(fields, key, groups,mod)
    chave = "#{key}_attributes"
    group = {chave => [:id, :_destroy]}
    groups.each do |field|
      if field[:sf].present? && field[:sf][:grupo].present?
        group[chave] << permitt_group(fields, field[:attribute], field[:sf][:fields], mod.reflect_on_association(key.to_s).class_name.constantize)
      else
        modelo = mod.reflect_on_association(key.to_s).class_name.constantize
        if modelo.reflect_on_association(field[:attribute])
          if modelo.reflect_on_association(field[:attribute]).macro == :belongs_to
            group[chave] << "#{field[:attribute]}_id".to_sym
          else
            group[chave] << {"#{field[:attribute].to_s.singularize}_ids".to_sym => []}
          end
        elsif (modelo.columns_hash[field[:attribute].to_s] || (modelo.respond_to?(:params_permitt) && modelo.params_permitt.include?(field[:attribute].to_sym)))
          if modelo.columns_hash[field[:attribute].to_s].cast_type.class == ActiveRecord::Type::Serialized
            group[chave] << {field[:attribute] => []}
          else
            group[chave] << field[:attribute]
          end
        end
      end
    end
    group
  end

  def valid_method?(method)
    list_methods = []
    @model.ancestors.each do |m|
      list_methods << m.methods(false).reject{ |m| /^_/ =~ m.to_s }
      break if m.superclass.to_s == "ActiveRecord::Base"
    end
    list_methods.flatten.include? method.to_sym
  end

  def valid_instance_method?(method)
    list_methods = []
    @model.ancestors.each do |m|
      list_methods << m.instance_methods(false).reject{ |m| /^_/ =~ m.to_s }
      break if m.superclass.to_s == "ActiveRecord::Base"
    end
    list_methods.flatten.include? method.to_sym
  end
end
