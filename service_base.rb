class ServiceExit < StandardError; end  # Exit early without error
class ServiceError < ServiceExit; end # Exit early and raise exception

class ServiceBase
  attr_reader :result, :errors, :params

  include DryService

  def initialize(params = {})
    @params  = params
  end

  def run!
    begin
      validate_params!
      setup
      execute
    rescue ServiceExit
      raise ServiceError.new(@errors) if failure?
    end

    @result
  end

  def setup
    # You *should* implement the extension method in your child class.
    # Use it to set reasonable defaults and parse out instance variables from params.
  end

  def execute
    # You *must* implement the extension method in your child class. (see example service file for example)
    raise NotImplementedError, "Subclasses must implement the execute method"
  end

  def success?
    @errors.blank?
  end

  def failure?
    !success?
  end

  protected

  def fail!(message = "", error_type = ServiceError, context = {})
    @errors = { error: message, error_type: }.merge(context)
    raise error_type, message
  end

  def exit_early!
    raise ServiceExit
  end
end

