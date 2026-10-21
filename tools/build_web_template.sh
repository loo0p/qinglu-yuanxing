#!/bin/sh
set -e
# 编译瘦身版 Web 导出模板（release · 单线程 · 去 3D/正则/SVG/网络等模块）→ 产物 bin/godot.web.template_release.wasm32.nothreads.zip
# 拷到 export/templates/web_nothreads_release_slim.zip。8 核约 5 分钟。
GBUILD=${GBUILD:-$HOME/godot-web-build}; mkdir -p "$GBUILD" && cd "$GBUILD"
[ -d godot ] || git clone -q --depth 1 -b 4.7.2-stable https://github.com/godotengine/godot.git
[ -d emsdk ] || git clone -q --depth 1 https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install 4.0.11 >/dev/null && ./emsdk activate 4.0.11 >/dev/null && . ./emsdk_env.sh >/dev/null 2>&1 && cd ..
python3 -m venv sv && ./sv/bin/pip -q install scons
cd godot
../sv/bin/scons platform=web target=template_release threads=no optimize=size_extra lto=none \
 disable_3d=yes disable_advanced_gui=no deprecated=no vulkan=no openxr=no use_volk=no \
 module_text_server_adv_enabled=no module_text_server_fb_enabled=yes \
 module_bmp_enabled=no module_camera_enabled=no module_csg_enabled=no module_dds_enabled=no module_enet_enabled=no \
 module_etcpak_enabled=no module_fbx_enabled=no module_gltf_enabled=no module_gridmap_enabled=no module_hdr_enabled=no \
 module_jsonrpc_enabled=no module_ktx_enabled=no module_lightmapper_rd_enabled=no module_mbedtls_enabled=no module_meshoptimizer_enabled=no \
 module_mobile_vr_enabled=no module_msdfgen_enabled=no module_multiplayer_enabled=no module_navigation_2d_enabled=no module_navigation_3d_enabled=no module_noise_enabled=no \
 module_openxr_enabled=no module_raycast_enabled=no module_regex_enabled=no module_squish_enabled=no module_svg_enabled=no module_tga_enabled=no \
 module_theora_enabled=no module_tinyexr_enabled=no module_upnp_enabled=no module_vhacd_enabled=no module_webrtc_enabled=no module_websocket_enabled=no \
 module_webxr_enabled=no module_xatlas_unwrap_enabled=no module_zip_enabled=no module_minimp3_enabled=no module_jolt_physics_enabled=no module_godot_physics_3d_enabled=no \
 module_interactive_music_enabled=no module_basis_universal_enabled=no module_astcenc_enabled=no module_cvtt_enabled=no module_betsy_enabled=no \
 -j8 2>&1 | tail -30
ls -la bin/
