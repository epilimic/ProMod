/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod GeoIP Extension
 * Copyright (C) 2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#include <sourcemod_version.h>
#include "extension.h"
#include "GeoIP.h"
#include "GeoIPCity.h"

/**
 * @file extension.cpp
 * @brief Implement extension code here.
 */
GeoIPCity_Extension g_GeoIPCity;
GeoIP *gi = NULL;
GeoIPRecord *gir = NULL;

SMEXT_LINK(&g_GeoIPCity);

bool GeoIPCity_Extension::SDK_OnLoad(char *error, size_t maxlength, bool late)
{
	char path[PLATFORM_MAX_PATH];

	g_pSM->BuildPath(Path_SM, path, sizeof(path), "configs/geoip/GeoIPCity.dat");

	// Use one of the following: GEOIP_STANDARD, GEOIP_MEMORY_CACHE
	// It's a tradeoff between memory usage and speed. Benchmarks: http://www.maxmind.com/app/benchmark
	gi = GeoIP_open(path, GEOIP_MEMORY_CACHE);

	// We need this in UTF8 for cities to display correctly
	GeoIP_set_charset(gi, GEOIP_CHARSET_UTF8);

	if (!gi)
	{
		snprintf(error, maxlength, "Could not load configs/geoip/GeoIPCity.dat");
		return false;
	}

	g_pShareSys->AddNatives(myself, geoipcity_natives);
	g_pShareSys->RegisterLibrary(myself, "GeoIPCity");
	g_pSM->LogMessage(myself, "GeoIP database info: %s", GeoIP_database_info(gi));

	return true;
}

void GeoIPCity_Extension::SDK_OnUnload()
{
	GeoIP_delete(gi);
	gi = NULL;
}

const char *GeoIPCity_Extension::GetExtensionVerString()
{
	return SM_FULL_VERSION;
}

const char *GeoIPCity_Extension::GetExtensionDateString()
{
	return SM_BUILD_TIMESTAMP;
}

/*******************************
*                              *
* GEOIP NATIVE IMPLEMENTATIONS *
*                              *
*******************************/

inline void StripPort(char *ip)
{
	char *tmp = strchr(ip, ':');
	if (!tmp)
		return;
	*tmp = '\0';
}

static cell_t sm_Geoip_Get_Record(IPluginContext *pCtx, const cell_t *params)
{
	char *ip;
	const char *region;

	// Grab the IP and strip the port
	pCtx->LocalToString(params[1], &ip);
	StripPort(ip);

	// Retrive the matching record in the database
	gir = GeoIP_record_by_addr(gi, ip);

	if (gir != NULL)
	{
		// Expose the data to SourceMod
		region = GeoIP_region_name_by_code(gir->country_code,gir->region);

		pCtx->StringToLocalUTF8(params[2], 45, gir->city ? gir->city : "", NULL);
		pCtx->StringToLocalUTF8(params[3], 45, region ? region : "", NULL);
		pCtx->StringToLocalUTF8(params[4], 45, gir->country_name ? gir->country_name : "", NULL);
		pCtx->StringToLocalUTF8(params[5], 3, gir->country_code ? gir->country_code : "", NULL);
		pCtx->StringToLocalUTF8(params[6], 4, gir->country_code3 ? gir->country_code3 : "", NULL);
	}

	// Return true if we found a match from the IP
	return gir ? 1 : 0;
}

const sp_nativeinfo_t geoipcity_natives[] = 
{
	{"GeoipGetRecord",		sm_Geoip_Get_Record},
	{NULL,					NULL},
};

