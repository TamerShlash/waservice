class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users, {id: false, primary_key: :jid} do |t|
      t.string :jid, null: :false
    end
  end

end
