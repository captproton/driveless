class FriendshipsController < ApplicationController

  before_filter :require_user

  def index
    @friends = current_user.friends_leaderboard_by(params[:mode_id])
    @fans = current_user.fans_leaderboard_by(params[:mode_id])
  end

  def show
    @friends = User.find_by_name(params[:username]).friends.by_green_miles.paginate(:page => params[:page] || 1)
    @fans = User.find( Friendship.of( User.find_by_name(params[:username]) ).map{|f| f.user_id} ).paginate(:page => params[:page] || 1)
  end

  def destroy
    current_user.unfriendship_to(params[:id])
    redirect_to account_friends_url
  end

  def new
  end

  def create
    current_user.friendship_to(params[:friend_id])
    redirect_to account_friends_url
  end

end
