import Foundation

extension LibraryViewModel {
    var activeSongs: [SongResponse] {
        songs.filter { !archivedSongIds.contains($0.id) }
    }

    var archivedSongs: [SongResponse] {
        songs.filter { archivedSongIds.contains($0.id) }
    }

    func archiveSong(_ song: SongResponse) {
        archivedSongIds.insert(song.id)
        SongArchiveStore.save(archivedSongIds)
    }

    func unarchiveSong(_ song: SongResponse) {
        archivedSongIds.remove(song.id)
        SongArchiveStore.save(archivedSongIds)
    }
}
