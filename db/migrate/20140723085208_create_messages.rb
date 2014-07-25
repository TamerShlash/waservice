class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.integer :conversation_id
      t.string :body
      t.integer :direction, default: 0
      t.timestamp :created_at
    end
  end
end
