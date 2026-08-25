class MergeVideoModalityIntoOnlineAndAddContactFields < ActiveRecord::Migration[8.0]
  def up
    # "video" (3) is being retired as a separate modality — it's the same
    # thing as "online" (1), just with a video-call link attached. Raw SQL
    # here (not the AR model) deliberately, so this runs correctly
    # regardless of whether the enum in app code still knows about "video".
    execute "UPDATE appointments SET modality = 1 WHERE modality = 3"
    execute "UPDATE provider_availabilities SET modality = 1 WHERE modality = 3"
    execute <<~SQL
      UPDATE services
      SET modalities = (
        SELECT array_agg(DISTINCT m ORDER BY m)
        FROM unnest(array_replace(modalities, 'video', 'online')) AS m
      )
      WHERE 'video' = ANY(modalities)
    SQL

    add_column :appointments, :video_call_link, :string
    add_column :appointments, :phone_number, :string
  end

  def down
    remove_column :appointments, :video_call_link
    remove_column :appointments, :phone_number
  end
end
