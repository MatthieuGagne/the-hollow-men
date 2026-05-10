<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.8" tiledversion="1.8.2" name="objects" tilewidth="16" tileheight="16" tilecount="2" columns="0" objectalignment="topleft">
 <tile id="0" type="instance">
  <properties>
   <property name="blocks_movement" type="bool" value="true"/>
   <property name="object_name" value="Desk"/>
   <property name="res_path" type="file" value="res://scenes/world/WorldObject.tscn"/>
   <property name="sprite_texture" type="file" value="res://assets/objects/desk_placeholder.png"/>
   <property name="tile_cols" type="int" value="3"/>
   <property name="tile_rows" type="int" value="1"/>
  </properties>
  <image source="../assets/objects/desk_placeholder.png" width="48" height="16"/>
 </tile>
 <tile id="1" type="instance">
  <properties>
   <property name="blocks_movement" type="bool" value="true"/>
   <property name="object_name" value="Iris"/>
   <property name="res_path" type="file" value="res://scenes/world/NPC.tscn"/>
   <property name="sprite_texture" type="file" value="res://assets/objects/iris.png"/>
   <property name="tile_cols" type="int" value="1"/>
   <property name="tile_rows" type="int" value="1"/>
  </properties>
  <image source="../assets/objects/iris.png" width="16" height="24"/>
 </tile>
</tileset>
