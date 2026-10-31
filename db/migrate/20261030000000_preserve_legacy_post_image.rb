class PreserveLegacyPostImage < ActiveRecord::Migration[8.1]
  def change
    rename_column :posts, :image, :legacy_image
  end
end
