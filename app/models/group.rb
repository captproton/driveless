class Group < ActiveRecord::Base
  has_many :memberships, :dependent => :destroy
  has_many :users, :through => :memberships

  belongs_to :owner, :class_name => "User"
  belongs_to :destination

  validates_presence_of :name, :owner_id, :destination_id
  validates_uniqueness_of :name

  named_scope :by_name , :order => 'name ASC'

  def self.find_leaderboard(group_ids_sql, user_id, order = :miles)
    order_sql = order.to_sym == :lb_co2 ? 'lb_co2_sum' : 'distance_sum'

    sql = <<-SQL
      SELECT groups.*, distance_sum, lb_co2_sum FROM groups
      INNER JOIN (

      SELECT group_id, sum(lb_co2_per_mode_sum) AS lb_co2_sum, sum(distance_per_mode_sum) AS distance_sum FROM (
        SELECT memberships.group_id, trips.mode_id, (modes.lb_co2_per_mile * sum(trips.distance)) AS lb_co2_per_mode_sum, sum(trips.distance) AS distance_per_mode_sum FROM trips
        INNER JOIN memberships ON trips.user_id = memberships.user_id
        INNER JOIN modes ON trips.mode_id = modes.id
        WHERE memberships.group_id IN
        (#{group_ids_sql})
        AND modes.green = ?
        GROUP BY memberships.group_id, trips.mode_id, modes.lb_co2_per_mile) AS stats_per_mode
      GROUP BY group_id) AS stats_per_group

      ON stats_per_group.group_id = groups.id
      ORDER BY #{order_sql} DESC
    SQL

    find_by_sql([sql, user_id, true])
  end

  def stats
    return @stats if @stats

    sql = <<-SQL
      SELECT groups.id, sum(lb_co2_per_mode_sum) AS lb_co2_sum, sum(distance_per_mode_sum) AS distance_sum FROM groups
      INNER JOIN (

        SELECT memberships.group_id, trips.mode_id, (modes.lb_co2_per_mile * sum(trips.distance)) AS lb_co2_per_mode_sum, sum(trips.distance) AS distance_per_mode_sum FROM trips
        INNER JOIN memberships ON trips.user_id = memberships.user_id
        INNER JOIN modes ON trips.mode_id = modes.id
        WHERE memberships.group_id = ?
        AND modes.green = ?
        GROUP BY memberships.group_id, trips.mode_id, modes.lb_co2_per_mile) AS stats_per_mode

      ON stats_per_mode.group_id = groups.id
      GROUP BY groups.id
    SQL

    c = self.class.find_by_sql([sql, id, true])[0]

    @stats = {
      :lb_co2_sum   => c.nil? ? 0 : c.lb_co2_sum,
      :distance_sum => c.nil? ? 0 : c.distance_sum
    }
  end

  def badges
    s = stats
    [
      {
        :stat => s[:distance_sum].to_i,
        :label => 'green miles'
      },
      {
        :stat => "%.2f" % s[:lb_co2_sum].to_f,
        :label => 'lb co2 saved'
      }
    ]
  end

  def self.find_leaderboard_owned_by(user, order = :miles)
    group_ids_sql = "SELECT id FROM groups WHERE owner_id = ?"

    find_leaderboard(group_ids_sql, user.id, order)
  end

  def self.find_leaderboard_for_member(user, order = :miles)
    group_ids_sql = "SELECT group_id FROM memberships WHERE user_id = ?"

    find_leaderboard(group_ids_sql, user.id, order)
  end

  def members_leaderboard(order)
    user_ids_sql = "SELECT user_id FROM memberships WHERE group_id = ?"

    User.find_leaderboard(user_ids_sql, id, order)
  end

  def members_leaderboard_by(mode_id)
    user_ids_sql = "SELECT user_id FROM memberships WHERE group_id = ?"

    User.find_leaderboard(user_ids_sql, id, :miles, mode_id)
  end

  def membership_for(user)
    memberships.find_by_user_id(user.id)
  end

  def owned_by?(user)
    owner_id == user.id
  end
end
