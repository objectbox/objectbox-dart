# Temporary workaround: avoid R8 failing to minify due to objectbox-sync-android-db including a keep
# rule for a class for Mesh Sync. As that class imports Nearby classes only available when also
# depending on objectbox-meshsync-android (such as via the objectbox_mesh_sync package), R8 fails.
-dontwarn io.objectbox.meshsync.android.internal.NearbyMeshNetwork*
