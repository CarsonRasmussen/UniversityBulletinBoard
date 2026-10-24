class CreateBulletinBoard < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.boolean :verified, null: false, default: false
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false
      t.string :category, null: false
      t.string :image
      t.timestamps
    end
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end
    [ :saved_posts, :likes ].each do |table|
      create_table table do |t|
        t.references :user, null: false, foreign_key: true
        t.references :post, null: false, foreign_key: true
        t.timestamps
      end
      add_index table, [ :user_id, :post_id ], unique: true
    end
  end
end
