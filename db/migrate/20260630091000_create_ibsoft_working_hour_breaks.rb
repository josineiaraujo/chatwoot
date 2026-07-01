class CreateIbsoftWorkingHourBreaks < ActiveRecord::Migration[7.1]
  def change
    create_table :ibsoft_working_hour_breaks do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :inbox, null: false, foreign_key: true, index: true
      t.integer :day_of_week, null: false
      t.integer :start_hour, null: false
      t.integer :start_minutes, null: false
      t.integer :end_hour, null: false
      t.integer :end_minutes, null: false

      t.timestamps
    end

    add_index :ibsoft_working_hour_breaks, [:inbox_id, :day_of_week],
              name: 'idx_ibsoft_working_hour_breaks_on_inbox_day'
  end
end
