/** Double-include prevention */
#if defined _miuwiki_map_chooser_
  #endinput
#endif
#define _miuwiki_map_chooser_


#define OFFICIAL_MAP 0
#define WORKSHOP_MAP 1

enum struct MapInfo
{
    int type;
    char missionfile[128];
    char missionname[128];
    char vpkname[128];

    ArrayList chapter;
}

/**
 * Get map list from plugin "miuwiki_mapchooser.smx"
 * 
 * @param map_type Get Official map use OFFICIAL_MAP, Workshop map use WORKSHOP_MAP
 * 
 * @return An arraylist contian all the map according to the map_type.
 * 
 * @note  To get the data about map, use MapInfo map = arraylist.GetArray(i, map)
 *        you should delete the Arraylist since it is clone from the origin handle in plugin.
 */
native ArrayList M_GetMapList(int map_type);
