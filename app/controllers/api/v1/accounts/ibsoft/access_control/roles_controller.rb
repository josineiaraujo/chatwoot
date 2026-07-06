class Api::V1::Accounts::Ibsoft::AccessControl::RolesController <
  Api::V1::Accounts::Ibsoft::AccessControl::BaseController
  before_action :fetch_role, only: [:show, :update, :destroy]

  def index
    render json: {
      roles: roles.map(&:payload),
      available_permissions: Ibsoft::AccessControl::PermissionCatalog.payload
    }
  end

  def show
    render json: @role.payload
  end

  def create
    role = Ibsoft::AccessControl::Role.create!(
      permitted_params.merge(account: Current.account)
    )

    render json: role.payload
  end

  def update
    @role.update!(permitted_params)

    render json: @role.payload
  end

  def destroy
    @role.destroy!

    head :no_content
  end

  private

  def roles
    @roles ||= Ibsoft::AccessControl::Role
               .includes(:role_assignments)
               .where(account: Current.account)
               .order(:name)
  end

  def fetch_role
    @role = Ibsoft::AccessControl::Role.find_by!(
      account: Current.account,
      id: params[:id]
    )
  end

  def permitted_params
    params.require(:role).permit(:name, :description, permissions: [])
  end
end
