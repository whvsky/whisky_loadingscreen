/*
 * WHISKY LOADSCREEN — MP4 PLAYLIST
 * Store your videos in html/assets/ and list them below.
 * This file is public. Keep Discord credentials in server_config.lua only.
 * All MP4 files in html/assets/ are automatically included by fxmanifest.lua.
 */
window.WhiskyMediaConfig = {
    defaultVolume: 35,  // 0-100
    autoNext: true,      // Automatically advance when an MP4 ends
    loopPlaylist: true,  // Start over after the last MP4 ends

    playlist: [
        { src: 'assets/background.mp4', title: 'Server Trailer' },
        // { src: 'assets/trailer2.mp4', title: 'Server Trailer' },
        // { src: 'assets/highlights.mp4', title: 'Community Highlights' }
    ]
};
