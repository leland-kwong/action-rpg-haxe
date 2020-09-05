<?xml version="1.0" encoding="UTF-8"?>
<data version="1.0">
    <struct type="Settings">
        <key>fileFormatVersion</key>
        <int>4</int>
        <key>texturePackerVersion</key>
        <string>5.4.0</string>
        <key>autoSDSettings</key>
        <array>
            <struct type="AutoSDSettings">
                <key>scale</key>
                <double>1</double>
                <key>extension</key>
                <string></string>
                <key>spriteFilter</key>
                <string></string>
                <key>acceptFractionalValues</key>
                <false/>
                <key>maxTextureSize</key>
                <QSize>
                    <key>width</key>
                    <int>-1</int>
                    <key>height</key>
                    <int>-1</int>
                </QSize>
            </struct>
        </array>
        <key>allowRotation</key>
        <false/>
        <key>shapeDebug</key>
        <false/>
        <key>dpi</key>
        <uint>72</uint>
        <key>dataFormat</key>
        <string>json</string>
        <key>textureFileName</key>
        <filename></filename>
        <key>flipPVR</key>
        <false/>
        <key>pvrCompressionQuality</key>
        <enum type="SettingsBase::PvrCompressionQuality">PVR_QUALITY_NORMAL</enum>
        <key>atfCompressData</key>
        <false/>
        <key>mipMapMinSize</key>
        <uint>32768</uint>
        <key>etc1CompressionQuality</key>
        <enum type="SettingsBase::Etc1CompressionQuality">ETC1_QUALITY_LOW_PERCEPTUAL</enum>
        <key>etc2CompressionQuality</key>
        <enum type="SettingsBase::Etc2CompressionQuality">ETC2_QUALITY_LOW_PERCEPTUAL</enum>
        <key>dxtCompressionMode</key>
        <enum type="SettingsBase::DxtCompressionMode">DXT_PERCEPTUAL</enum>
        <key>jxrColorFormat</key>
        <enum type="SettingsBase::JpegXrColorMode">JXR_YUV444</enum>
        <key>jxrTrimFlexBits</key>
        <uint>0</uint>
        <key>jxrCompressionLevel</key>
        <uint>0</uint>
        <key>ditherType</key>
        <enum type="SettingsBase::DitherType">NearestNeighbour</enum>
        <key>backgroundColor</key>
        <uint>0</uint>
        <key>libGdx</key>
        <struct type="LibGDX">
            <key>filtering</key>
            <struct type="LibGDXFiltering">
                <key>x</key>
                <enum type="LibGDXFiltering::Filtering">Linear</enum>
                <key>y</key>
                <enum type="LibGDXFiltering::Filtering">Linear</enum>
            </struct>
        </struct>
        <key>shapePadding</key>
        <uint>1</uint>
        <key>jpgQuality</key>
        <uint>80</uint>
        <key>pngOptimizationLevel</key>
        <uint>0</uint>
        <key>webpQualityLevel</key>
        <uint>101</uint>
        <key>textureSubPath</key>
        <string></string>
        <key>atfFormats</key>
        <string></string>
        <key>textureFormat</key>
        <enum type="SettingsBase::TextureFormat">png</enum>
        <key>borderPadding</key>
        <uint>0</uint>
        <key>maxTextureSize</key>
        <QSize>
            <key>width</key>
            <int>2048</int>
            <key>height</key>
            <int>2048</int>
        </QSize>
        <key>fixedTextureSize</key>
        <QSize>
            <key>width</key>
            <int>-1</int>
            <key>height</key>
            <int>-1</int>
        </QSize>
        <key>algorithmSettings</key>
        <struct type="AlgorithmSettings">
            <key>algorithm</key>
            <enum type="AlgorithmSettings::AlgorithmId">MaxRects</enum>
            <key>freeSizeMode</key>
            <enum type="AlgorithmSettings::AlgorithmFreeSizeMode">Best</enum>
            <key>sizeConstraints</key>
            <enum type="AlgorithmSettings::SizeConstraints">AnySize</enum>
            <key>forceSquared</key>
            <false/>
            <key>maxRects</key>
            <struct type="AlgorithmMaxRectsSettings">
                <key>heuristic</key>
                <enum type="AlgorithmMaxRectsSettings::Heuristic">Best</enum>
            </struct>
            <key>basic</key>
            <struct type="AlgorithmBasicSettings">
                <key>sortBy</key>
                <enum type="AlgorithmBasicSettings::SortBy">Best</enum>
                <key>order</key>
                <enum type="AlgorithmBasicSettings::Order">Ascending</enum>
            </struct>
            <key>polygon</key>
            <struct type="AlgorithmPolygonSettings">
                <key>alignToGrid</key>
                <uint>1</uint>
            </struct>
        </struct>
        <key>dataFileNames</key>
        <map type="GFileNameMap">
            <key>data</key>
            <struct type="DataFile">
                <key>name</key>
                <filename>../res/sprite_sheet.json</filename>
            </struct>
        </map>
        <key>multiPack</key>
        <false/>
        <key>forceIdenticalLayout</key>
        <false/>
        <key>outputFormat</key>
        <enum type="SettingsBase::OutputFormat">RGBA8888</enum>
        <key>alphaHandling</key>
        <enum type="SettingsBase::AlphaHandling">ClearTransparentPixels</enum>
        <key>contentProtection</key>
        <struct type="ContentProtection">
            <key>key</key>
            <string></string>
        </struct>
        <key>autoAliasEnabled</key>
        <true/>
        <key>trimSpriteNames</key>
        <true/>
        <key>prependSmartFolderName</key>
        <false/>
        <key>autodetectAnimations</key>
        <true/>
        <key>globalSpriteSettings</key>
        <struct type="SpriteSettings">
            <key>scale</key>
            <double>1</double>
            <key>scaleMode</key>
            <enum type="ScaleMode">Smooth</enum>
            <key>extrude</key>
            <uint>1</uint>
            <key>trimThreshold</key>
            <uint>1</uint>
            <key>trimMargin</key>
            <uint>1</uint>
            <key>trimMode</key>
            <enum type="SpriteSettings::TrimMode">CropKeepPos</enum>
            <key>tracerTolerance</key>
            <int>200</int>
            <key>heuristicMask</key>
            <false/>
            <key>defaultPivotPoint</key>
            <point_f>0.5,0.5</point_f>
            <key>writePivotPoints</key>
            <true/>
        </struct>
        <key>individualSpriteSettings</key>
        <map type="IndividualSpriteSettingsMap">
            <key type="filename">aseprite_exports/base_palette/.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>4,1,8,1</rect>
                <key>scale9Paddings</key>
                <rect>4,1,8,1</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/destroy_animation/default-0.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-1.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-10.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-11.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-12.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-2.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-3.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-4.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-5.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-6.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-7.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-8.png</key>
            <key type="filename">aseprite_exports/destroy_animation/default-9.png</key>
            <key type="filename">aseprite_exports/explosion_animation/default-0.png</key>
            <key type="filename">aseprite_exports/spider_bot_animation/idle-0.png</key>
            <key type="filename">aseprite_exports/spider_bot_animation/walk_run-0.png</key>
            <key type="filename">aseprite_exports/spider_bot_animation/walk_run-1.png</key>
            <key type="filename">aseprite_exports/spider_bot_animation/walk_run-2.png</key>
            <key type="filename">aseprite_exports/spider_bot_animation/walk_run-3.png</key>
            <key type="filename">aseprite_exports/spider_bot_animation/walk_run-4.png</key>
            <key type="filename">aseprite_exports/ui/circle_gradient.png</key>
            <key type="filename">aseprite_exports/ui/enemy_spawn_point.png</key>
            <key type="filename">aseprite_exports/ui/placeholder.png</key>
            <key type="filename">aseprite_exports/ui/square_tile_test.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_10.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_11.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_12.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_13.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_14.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_15.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_8.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_9.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>4,4,8,8</rect>
                <key>scale9Paddings</key>
                <rect>4,4,8,8</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-0.png</key>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-1.png</key>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-2.png</key>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-3.png</key>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-4.png</key>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-5.png</key>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-6.png</key>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-7.png</key>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-8.png</key>
            <key type="filename">aseprite_exports/enemy-1_animation/idle-9.png</key>
            <key type="filename">aseprite_exports/ui/melee_burst.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>5,5,10,10</rect>
                <key>scale9Paddings</key>
                <rect>5,5,10,10</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/enemy-2_animation/idle-0.png</key>
            <key type="filename">aseprite_exports/enemy-2_animation/idle-1.png</key>
            <key type="filename">aseprite_exports/enemy-2_animation/move-0.png</key>
            <key type="filename">aseprite_exports/enemy-2_animation/move-1.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.525,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>10,13,20,25</rect>
                <key>scale9Paddings</key>
                <rect>10,13,20,25</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/intro_boss_animation/idle-0.png</key>
            <key type="filename">aseprite_exports/intro_boss_animation/walk-0.png</key>
            <key type="filename">aseprite_exports/intro_boss_animation/walk-1.png</key>
            <key type="filename">aseprite_exports/intro_boss_animation/walk-2.png</key>
            <key type="filename">aseprite_exports/intro_boss_animation/walk-3.png</key>
            <key type="filename">aseprite_exports/intro_boss_animation/walk-4.png</key>
            <key type="filename">aseprite_exports/intro_boss_animation/walk-5.png</key>
            <key type="filename">aseprite_exports/intro_boss_animation/walk-6.png</key>
            <key type="filename">aseprite_exports/intro_boss_animation/walk-7.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.515,0.583333</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>50,30,100,60</rect>
                <key>scale9Paddings</key>
                <rect>50,30,100,60</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/player_animation/attack-0.png</key>
            <key type="filename">aseprite_exports/player_animation/attack-1.png</key>
            <key type="filename">aseprite_exports/player_animation/attack-2.png</key>
            <key type="filename">aseprite_exports/player_animation/attack-3.png</key>
            <key type="filename">aseprite_exports/player_animation/attack-4.png</key>
            <key type="filename">aseprite_exports/player_animation/idle-0.png</key>
            <key type="filename">aseprite_exports/player_animation/run-0.png</key>
            <key type="filename">aseprite_exports/player_animation/run-1.png</key>
            <key type="filename">aseprite_exports/player_animation/run-2.png</key>
            <key type="filename">aseprite_exports/player_animation/run-3.png</key>
            <key type="filename">aseprite_exports/player_animation/run-4.png</key>
            <key type="filename">aseprite_exports/player_animation/run-5.png</key>
            <key type="filename">aseprite_exports/player_animation/run-6.png</key>
            <key type="filename">aseprite_exports/player_animation/run-7.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.357143,0.75</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>13,8,25,15</rect>
                <key>scale9Paddings</key>
                <rect>13,8,25,15</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/projectile_hit_animation/burst-0.png</key>
            <key type="filename">aseprite_exports/projectile_hit_animation/burst-1.png</key>
            <key type="filename">aseprite_exports/projectile_hit_animation/burst-2.png</key>
            <key type="filename">aseprite_exports/projectile_hit_animation/burst-3.png</key>
            <key type="filename">aseprite_exports/projectile_hit_animation/burst-4.png</key>
            <key type="filename">aseprite_exports/projectile_hit_animation/burst-5.png</key>
            <key type="filename">aseprite_exports/projectile_hit_animation/burst-6.png</key>
            <key type="filename">aseprite_exports/projectile_hit_animation/burst-7.png</key>
            <key type="filename">aseprite_exports/ui/bullet_enemy_large.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>4,4,7,7</rect>
                <key>scale9Paddings</key>
                <rect>4,4,7,7</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/aura_glyph_1.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>7,7,15,15</rect>
                <key>scale9Paddings</key>
                <rect>7,7,15,15</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/bridge_vertical.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>43,56,86,112</rect>
                <key>scale9Paddings</key>
                <rect>43,56,86,112</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/bullet_player_basic.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>4,4,8,7</rect>
                <key>scale9Paddings</key>
                <rect>4,4,8,7</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/cockpit_resource_bar_energy.png</key>
            <key type="filename">aseprite_exports/ui/cockpit_resource_bar_health.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>2,1,3,2</rect>
                <key>scale9Paddings</key>
                <rect>2,1,3,2</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/cockpit_underlay.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,1</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>37,4,74,7</rect>
                <key>scale9Paddings</key>
                <rect>37,4,74,7</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/energy_bomb_projectile.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>2,2,3,3</rect>
                <key>scale9Paddings</key>
                <rect>2,2,3,3</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/energy_bomb_ring.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>2,2,5,5</rect>
                <key>scale9Paddings</key>
                <rect>2,2,5,5</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/flame_torch.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.117647,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>7,2,14,5</rect>
                <key>scale9Paddings</key>
                <rect>7,2,14,5</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/hud_ability_slot.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_basic_blaster.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_basic_blaster_evolved.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_burst_charge.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_channel_beam.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_energy_1.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_energy_bomb.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_flame_torch.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_heal_1.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_movespeed_aura.png</key>
            <key type="filename">aseprite_exports/ui/loot__ability_spider_bots.png</key>
            <key type="filename">aseprite_exports/ui/ui_inventory_slot.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>6,6,11,11</rect>
                <key>scale9Paddings</key>
                <rect>6,6,11,11</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/hud_experience_progress.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>30,0,59,1</rect>
                <key>scale9Paddings</key>
                <rect>30,0,59,1</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/hud_inventory_button--hover.png</key>
            <key type="filename">aseprite_exports/ui/hud_inventory_button.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,0</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>2,2,5,5</rect>
                <key>scale9Paddings</key>
                <rect>2,2,5,5</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/hud_passive_skill_tree_button--hover.png</key>
            <key type="filename">aseprite_exports/ui/hud_passive_skill_tree_button.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,0</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>3,3,5,5</rect>
                <key>scale9Paddings</key>
                <rect>3,3,5,5</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/hud_player_level.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>3,2,5,3</rect>
                <key>scale9Paddings</key>
                <rect>3,2,5,3</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/kamehameha_center_width_1.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>0,4,1,7</rect>
                <key>scale9Paddings</key>
                <rect>0,4,1,7</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/kamehameha_center_width_2.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>0,4,1,9</rect>
                <key>scale9Paddings</key>
                <rect>0,4,1,9</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/kamehameha_center_width_3.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>0,5,1,11</rect>
                <key>scale9Paddings</key>
                <rect>0,5,1,11</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/kamehameha_head.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>6,6,11,13</rect>
                <key>scale9Paddings</key>
                <rect>6,6,11,13</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/kamehameha_tail.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>1,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>4,5,7,9</rect>
                <key>scale9Paddings</key>
                <rect>4,5,7,9</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/loot_effect_legendary_gradient.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,1</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>0,70,1,141</rect>
                <key>scale9Paddings</key>
                <rect>0,70,1,141</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/notification_gradient.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>50,0,100,1</rect>
                <key>scale9Paddings</key>
                <rect>50,0,100,1</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/npc_test_dummy.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>3,7,6,13</rect>
                <key>scale9Paddings</key>
                <rect>3,7,6,13</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__link_diagonal.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>3,3,6,6</rect>
                <key>scale9Paddings</key>
                <rect>3,3,6,6</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__link_fork.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>8,5,15,9</rect>
                <key>scale9Paddings</key>
                <rect>8,5,15,9</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__link_fork_vert.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>5,8,9,15</rect>
                <key>scale9Paddings</key>
                <rect>5,8,9,15</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__link_horizontal.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>6,0,13,1</rect>
                <key>scale9Paddings</key>
                <rect>6,0,13,1</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__link_vertical.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>0,6,1,13</rect>
                <key>scale9Paddings</key>
                <rect>0,6,1,13</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__node_blue.png</key>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__node_green.png</key>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__node_orange.png</key>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__node_red.png</key>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__node_root.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>6,6,13,13</rect>
                <key>scale9Paddings</key>
                <rect>6,6,13,13</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__node_fist.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>9,9,19,19</rect>
                <key>scale9Paddings</key>
                <rect>9,9,19,19</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__node_size_1_selected_state.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>8,8,15,15</rect>
                <key>scale9Paddings</key>
                <rect>8,8,15,15</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/passive_skill_tree__node_size_2_selected_state.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>11,11,21,21</rect>
                <key>scale9Paddings</key>
                <rect>11,11,21,21</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/pillar.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.636364</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>11,22,21,44</rect>
                <key>scale9Paddings</key>
                <rect>11,22,21,44</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/player_pet_orb.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,1</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>1,7,3,13</rect>
                <key>scale9Paddings</key>
                <rect>1,7,3,13</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/player_pet_orb_shadow.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>1,1,3,1</rect>
                <key>scale9Paddings</key>
                <rect>1,1,3,1</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/prop_1_1.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>3,4,5,7</rect>
                <key>scale9Paddings</key>
                <rect>3,4,5,7</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/prop_1_1_shard_1.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>2,1,5,3</rect>
                <key>scale9Paddings</key>
                <rect>2,1,5,3</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/prop_1_1_shard_2.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>2,2,3,5</rect>
                <key>scale9Paddings</key>
                <rect>2,2,3,5</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/prop_1_1_shard_3.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>1,2,3,5</rect>
                <key>scale9Paddings</key>
                <rect>1,2,3,5</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/square_glow.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>1,1,1,1</rect>
                <key>scale9Paddings</key>
                <rect>1,1,1,1</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/square_white.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,0</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>0,0,1,1</rect>
                <key>scale9Paddings</key>
                <rect>0,0,1,1</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/stylized_border_1.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>16,1,31,3</rect>
                <key>scale9Paddings</key>
                <rect>16,1,31,3</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/teleporter_base.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.317708,0.375723</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>48,43,96,87</rect>
                <key>scale9Paddings</key>
                <rect>48,43,96,87</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/teleporter_pillar_left.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.529412,0.833333</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>4,12,9,24</rect>
                <key>scale9Paddings</key>
                <rect>4,12,9,24</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/teleporter_pillar_right.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.470588,0.833333</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>4,12,9,24</rect>
                <key>scale9Paddings</key>
                <rect>4,12,9,24</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/tile_1_0.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_1.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_2.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_3.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_4.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_5.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_6.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_7.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.138462</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>5,16,9,33</rect>
                <key>scale9Paddings</key>
                <rect>5,16,9,33</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/tile_1_10.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_11.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_12.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_13.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_14.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_15.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_16.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_17.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_18.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_19.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_8.png</key>
            <key type="filename">aseprite_exports/ui/tile_1_9.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.138462</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>5,5,9,9</rect>
                <key>scale9Paddings</key>
                <rect>5,5,9,9</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/tile_1_detail_1.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>11,6,21,11</rect>
                <key>scale9Paddings</key>
                <rect>11,6,21,11</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/tile_1_detail_2.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.183673</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>5,12,9,25</rect>
                <key>scale9Paddings</key>
                <rect>5,12,9,25</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/tile_2_0.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_1.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_2.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_3.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_4.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_5.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_6.png</key>
            <key type="filename">aseprite_exports/ui/tile_2_7.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.156863</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>4,13,8,25</rect>
                <key>scale9Paddings</key>
                <rect>4,13,8,25</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/ui_inventory_ability_slots_group.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>1,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>25,8,49,15</rect>
                <key>scale9Paddings</key>
                <rect>25,8,49,15</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/ui_inventory_underlay.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>1,0</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>69,49,139,97</rect>
                <key>scale9Paddings</key>
                <rect>69,49,139,97</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui_cursor_animation/default-0.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>8,8,16,16</rect>
                <key>scale9Paddings</key>
                <rect>8,8,16,16</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui_passive_tree/.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>125,125,250,250</rect>
                <key>scale9Paddings</key>
                <rect>125,125,250,250</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
        </map>
        <key>fileList</key>
        <array>
            <filename>aseprite_exports</filename>
        </array>
        <key>ignoreFileList</key>
        <array/>
        <key>replaceList</key>
        <array/>
        <key>ignoredWarnings</key>
        <array/>
        <key>commonDivisorX</key>
        <uint>1</uint>
        <key>commonDivisorY</key>
        <uint>1</uint>
        <key>packNormalMaps</key>
        <false/>
        <key>autodetectNormalMaps</key>
        <true/>
        <key>normalMapFilter</key>
        <string></string>
        <key>normalMapSuffix</key>
        <string></string>
        <key>normalMapSheetFileName</key>
        <filename></filename>
        <key>exporterProperties</key>
        <map type="ExporterProperties"/>
    </struct>
</data>
