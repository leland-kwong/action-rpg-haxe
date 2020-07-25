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
        <uint>0</uint>
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
                <point_f>0.5,0.68387</point_f>
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
                <point_f>0.5,0.5</point_f>
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
            <key type="filename">aseprite_exports/ui/hud_ability_slot.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>17,6,34,11</rect>
                <key>scale9Paddings</key>
                <rect>17,6,34,11</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/hud_inventory_button.png</key>
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
                <point_f>0,0.5</point_f>
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
            <key type="filename">aseprite_exports/ui/level_intro.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.5</point_f>
                <key>spriteScale</key>
                <double>1</double>
                <key>scale9Enabled</key>
                <false/>
                <key>scale9Borders</key>
                <rect>380,296,760,592</rect>
                <key>scale9Paddings</key>
                <rect>380,296,760,592</rect>
                <key>scale9FromFile</key>
                <false/>
            </struct>
            <key type="filename">aseprite_exports/ui/loot__ability_spider_bot.png</key>
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
            <key type="filename">aseprite_exports/ui/teleporter_pillar_left.png</key>
            <key type="filename">aseprite_exports/ui/teleporter_pillar_right.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0.5,0.833333</point_f>
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
            <key type="filename">aseprite_exports/ui/ui_inventory_underlay.png</key>
            <struct type="IndividualSpriteSettings">
                <key>pivotPoint</key>
                <point_f>0,1</point_f>
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
