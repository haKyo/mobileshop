class OrdersController < ApplicationController
  before_action :current_cart, only: %i(new create)
  before_action :find_order, only: %i(show update)
  before_action :find_order_product_code, only: :edit
  before_action :create_order, only: :create

  def new
    cart.line_items.empty? ? redirect_to(root_path) : (@order = Order.new)
  end

  def create
    order.update_attributes product_code: generate
    order.add_line_items_from_cart cart

    if order.save
      create_success
      create_notification order
    else
      render :new
    end
  end

  def show
    @line_items = order.line_items
    user_signed_in? ? current_order : redirect_to(root_path)
  end

  def edit
    if order
      @line_items = order_line_items
      @line_item = order_line_items.first
    else
      redirect_to root_path
    end
  end

  def update
    order.update_attributes order_status: :cancelled if order.processing?
    redirect_to order
  end

  private

  attr_reader :cart, :order, :line_items, :line_item,
    :generate, :order_product_code

  def current_order
    return if current_user.orders.find_by id: params[:id]
    redirect_to root_path
  end

  def order_line_items
    order.line_items
  end

  def find_order_product_code
    @order = Order.find_by id: params[:id],
      product_code: params[:product_code]
    failed_order
  end

  def find_order
    @order = Order.find_by id: params[:id]
    failed_order
  end

  def failed_order
    return if order
    flash[:warning] = t "failed_order"
    redirect_to root_path
  end

  def order_params
    params.require(:order).permit :name, :email, :address, :phone
  end

  def create_order
    @order = if current_user
               current_user.orders.build order_params
             else
               Order.new order_params
             end
    @generate = (Settings.zero...Settings.eight)
      .map{(Settings.generate + rand(Settings.rand)).chr}.join
  end

  def create_success
    Cart.destroy session[:cart_id]
    session[:card_id] = nil
    redirect_to root_url
    flash[:success] = current_user ? t("thank") : t("check")
  end

  def create_notification order
    ProductCodeMailer.product_code(order).deliver_now if current_user.blank?
    Notification.create content: "new_order", order_url: admin_order_path(order)
    ActionCable.server.broadcast "notification_channel", message: "success"
  end
end
