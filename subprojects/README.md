To update libgnome-games-support:

 * Update the hash in libgnome-games-support.wrap
 * Build the game using Meson. Meson will automatically download the new subproject version
 * rm -rf subprojects/libgnome-games-support/.git
