class Api::V1::Accounts::Ibsoft::Erp::ConnectionsController < Api::V1::Accounts::Ibsoft::Erp::BaseController
  before_action :set_connection, only: [:show, :update, :destroy, :test_connection]

  def index
    render json: {
      providers: Ibsoft::Erp::Connection.providers_payload,
      connections: scoped_connections.map(&:payload)
    }
  end

  def show
    render json: @connection.payload
  end

  def create
    connection = Ibsoft::Erp::Connection.new(connection_attributes.merge(account: Current.account))
    connection.save!

    render json: connection.payload
  end

  def update
    @connection.update!(connection_attributes)

    render json: @connection.payload
  end

  def destroy
    @connection.destroy!

    head :no_content
  end

  def test_connection
    result = Ibsoft::Erp::ConnectionTester.new(@connection).call

    render json: {
      connection: @connection.reload.payload,
      test: result.payload
    }
  end

  private

  def scoped_connections
    Ibsoft::Erp::Connection.where(account: Current.account).order(active: :desc, name: :asc)
  end

  def set_connection
    @connection = scoped_connections.find(params[:id])
  end

  def connection_attributes
    attrs = params.permit(:name, :provider, :auth_type, :base_url, :active).to_h
    attrs[:settings] = settings_attributes if params.key?(:settings)
    attrs[:credentials] = credential_attributes if params.key?(:credentials)
    attrs
  end

  def settings_attributes
    return {} unless params[:settings].respond_to?(:to_unsafe_h)

    params[:settings].to_unsafe_h
  end

  def credential_attributes
    incoming = params[:credentials].respond_to?(:to_unsafe_h) ? params[:credentials].to_unsafe_h : {}
    sanitized_credentials = incoming.deep_stringify_keys
                                    .transform_values { |value| value.is_a?(String) ? value.strip : value }
                                    .reject { |_key, value| value.blank? }

    return sanitized_credentials if @connection.blank?

    @connection.credentials.to_h.merge(sanitized_credentials)
  end
end
