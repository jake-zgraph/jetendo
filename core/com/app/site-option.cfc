<cfcomponent extends="zcorerootmapping.com.app.option-base">
<cfoutput> 
<cffunction name="getOptionTypes" returntype="struct" localmode="modern" access="public">
	<cfscript>
	ts=getOptionTypeCFCs();
	for(i in ts){
		ts[i].init("site", "site");
	}
	return ts;
	</cfscript>
</cffunction>
 

<cffunction name="getTypeData" returntype="struct" localmode="modern" access="public">
	<cfargument name="site_id" type="string" required="yes" hint="site_id">
	<cfscript>
	return application.siteStruct[arguments.site_id].globals.soGroupData;
	</cfscript>
</cffunction>
 
<cffunction name="processSearchArraySQL" access="private" output="no" returntype="string" localmode="modern">
	<cfargument name="arrSearch" type="array" required="yes"> 
	<cfargument name="fieldStruct" type="struct" required="yes">
	<cfargument name="tableCount" type="numeric" required="yes"> 
	<cfargument name="site_option_group_id" type="string" required="yes">
	<cfscript> 
	length=arraylen(arguments.arrSearch);
	lastMatch=true;
	arrSQL=[' ( '];
	t9=getSiteData();
	for(i=1;i LTE length;i++){
		c=arguments.arrSearch[i]; 
		if(isArray(c)){
			sql=this.processSearchArraySQL(c, arguments.fieldStruct, arguments.tableCount, arguments.site_option_group_id);
			arrayAppend(arrSQL, sql); 
		}else if(isStruct(c)){
			if(structkeyexists(c, 'subGroup')){
				throw("subGroup, ""#c.subGroup#"", has caching disabled. subGroup search is not supported yet when caching is disabled (i.e. site_option_group_enable_cache = 0).");
			}else{
				siteOptionId=t9.siteOptionIdLookup[arguments.site_option_group_id&chr(9)&c.field];
				if(not structkeyexists(arguments.fieldStruct, siteOptionId)){
					arguments.fieldStruct[siteOptionId]=arguments.tableCount;
					arguments.tableCount++;
				} 
				if(application.zcore.functions.zso(t9.siteOptionLookup[siteOptionId].optionStruct,'selectmenu_multipleselection', true, 0) EQ 1){
					multipleValues=true;
					if(t9.siteOptionLookup[siteOptionId].optionStruct.selectmenu_delimiter EQ "|"){
						delimiter=',';
					}else{
						delimiter='|';
					}
				}else{
					multipleValues=false;
					delimiter='';
				}
				if(structkeyexists(c, 'concatAppendPrepend')){
					concatAppendPrepend=c.concatAppendPrepend;
				}else{
					concatAppendPrepend='';
				}
				tableName="sGroup"&arguments.fieldStruct[siteOptionId];
				field='sVal'&siteOptionId;
				currentCFC=application.zcore.siteOptionCom.getTypeCFC(t9.siteOptionLookup[siteOptionId].site_option_type_id);
				fieldName=currentCFC.getSearchFieldName('s1', tableName, t9.siteOptionLookup[siteOptionId].optionStruct);
				arrayAppend(arrSQL, this.processSearchGroupSQL(c, fieldName, multipleValues, delimiter, concatAppendPrepend));// "`"&tableName&"`.`"&field&"`"));
				if(i NEQ length and not isSimpleValue(arguments.arrSearch[i+1])){
					arrayAppend(arrSQL, ' and ');
				}
			}
		}else if(c EQ "OR"){
			if(i EQ 1 or i EQ length){
				throw("""OR"" must be between an array or struct, not at the beginning or end or the array.");
			}
			arrayAppend(arrSQL, 'or');
		}else if(c EQ "AND"){
			if(i EQ 1 or i EQ length){
				throw("""AND"" must be between an array or struct, not at the beginning or end or the array.");
			}
			arrayAppend(arrSQL, 'and');
		}else{
			savecontent variable="output"{
				writedump(c);
			}
			throw("Invalid data type.  Dump of object:"&c);
		}
	}
	if(arrayLen(arrSQL) EQ 1){
		arrayAppend(arrSQL, "1=1");
	}
	arrayAppend(arrSQL, ' ) ');
	return arrayToList(arrSQL, " ");
	</cfscript>
</cffunction>


<cffunction name="processSearchArray" access="private" output="yes" returntype="boolean" localmode="modern">
	<cfargument name="arrSearch" type="array" required="yes">
	<cfargument name="row" type="struct" required="yes">
	<cfargument name="site_option_group_id" type="string" required="yes">
	<cfscript>
	row=arguments.row;
	length=arraylen(arguments.arrSearch);
	lastMatch=true;
	if(length EQ 0){
		return true;
	}
	debugOn=false;
	typeStruct=getTypeData(request.zos.globals.id); 
	for(i=1;i LTE length;i++){
		c=arguments.arrSearch[i]; 
		if(debugOn){ echo('<hr>');	writedump(c);	}
		if(isArray(c)){
			if(debugOn){
				echo("before processSearchArray<br>");
			}
			lastMatch=this.processSearchArray(c, row, arguments.site_option_group_id); 
			if(debugOn){
				echo("processSearchArray lastMatch:"&lastMatch&"<br>");
			}
		}else if(isStruct(c)){
			if(i NEQ 1 and not isSimpleValue(arguments.arrSearch[i])){
				if(not lastMatch){
					// the entire group must be valid or we return false.
					if(debugOn){
						echo("continue prevented struct matching from running<br>");
					}
					continue;
				}
			}
			if(structkeyexists(c, 'subGroup')){
				if(debugOn){ echo('in subgroup<br>');	}
				/*if(not structkeyexists(request.zos.siteOptionSearchSubGroupCache, c.subGroup)){
					groupStruct=application.zcore.functions.zGetSiteOptionGroupById(row.__groupId);
					groupId=application.zcore.functions.zGetSiteOptionGroupIdWithNameArray([groupStruct.site_option_group_name, c.subGroup]);
					childGroupStruct=application.zcore.functions.zGetSiteOptionGroupById(groupId);
					// the child group MUST be cached in memory since we don't support subGroup on processSearchArraySQL yet.
					request.zos.siteOptionSearchSubGroupCache[c.subGroup]=application.zcore.functions.zSiteOptionGroupStruct(c.subGroup, 0, request.zos.globals.id, row);
				}*/
				arrChild=application.zcore.functions.zSiteOptionGroupStruct(c.subGroup, 0, request.zos.globals.id, row);//request.zos.siteOptionSearchSubGroupCache[c.subGroup];
				lastMatch=false;
				if(arrayLen(arrChild)){
					//writedump(arrChild); 
					siteOptionId=typeStruct.siteOptionIdLookup[arrChild[1].__groupId&chr(9)&c.field];
					if(application.zcore.functions.zso(typeStruct.siteOptionLookup[siteOptionId].optionStruct,'selectmenu_multipleselection', true, 0) EQ 1){
						multipleValues=true;
						if(typeStruct.siteOptionLookup[siteOptionId].optionStruct.selectmenu_delimiter EQ "|"){
							delimiter=',';
						}else{
							delimiter='|';
						}
					}else{
						multipleValues=false;
						delimiter='';
					}
					for(n=1;n LTE arrayLen(arrChild);n++){
						c2=arrChild[n]; 
						if(debugOn){ /* writedump(c); writedump(c2); */ 	}
						lastMatch=this.processSearchGroup(c, c2, multipleValues, delimiter); 
						if(lastMatch){
							// always return true if at least one child group matches. I.e. If a product has a "color" sub-group.  User searches for "red", then the product would be valid even if it has other options like "blue".
							break;
						}
					}
					/*writedump(lastMatch);					writedump(row);					writedump(childGroupStruct);					abort;*/
				}
				if(debugOn){
					echo("child lastMatch:"&lastMatch&"<br>");
				}
			}else{ 
				siteOptionId=typeStruct.siteOptionIdLookup[arguments.site_option_group_id&chr(9)&c.field];
				if(application.zcore.functions.zso(typeStruct.siteOptionLookup[siteOptionId].optionStruct,'selectmenu_multipleselection', true, 0) EQ 1){
					multipleValues=true;
					if(typeStruct.siteOptionLookup[siteOptionId].optionStruct.selectmenu_delimiter EQ "|"){
						delimiter=',';
					}else{
						delimiter='|';
					}
				}else{
					multipleValues=false;
					delimiter='';
				}
				
				if(debugOn){
					echo("before processSearchGroup:<br />");
				}
				lastMatch=this.processSearchGroup(c, row, multipleValues, delimiter); 
				if(debugOn){
					echo("processSearchGroup lastMatch:"&lastMatch&"<br>");
				}
			}
		}else if(c EQ "OR"){
			if(debugOn){
				echo("OR<br />");
			}
			if(i EQ 1 or i EQ length){
				throw("""OR"" must be between an array or struct, not at the beginning or end or the array.");
			}
			if(lastMatch){
				if(debugOn){
					echo("returning in OR<br />");
				}
				return true;
			}
			lastMatch=true;
		}else if(c EQ "AND"){
			if(debugOn){
				echo("AND<br />");
			}
			if(i EQ 1 or i EQ length){
				throw("""AND"" must be between an array or struct, not at the beginning or end or the array.");
			}
			if(not lastMatch){
				if(debugOn){
					echo("returning in AND<br />");
				}
				return false;
			}
		}else{
			savecontent variable="output"{
				writedump(c);
			}
			throw("Invalid data type.  Dump of object:"&c);
		}
	}
	if(debugOn){
		echo('final lastMatch:'&lastMatch&'<hr />');
		//abort;
	}
	return lastMatch;
	</cfscript>
</cffunction>


 
<!--- 
// nested in-memory search is WORKING for all types.
ts=[
	{
		type="=",
		field: "User Id",
		arrValue:[request.zsession.user.id]	
	},
	'OR',
	[
		{
			type="not like",
			field: "title",
			arrValue:["pizza"]
		},
		'AND',
		{
			type="like",
			field: "title",
			arrValue:["3 Wishes%"]
		},
		'AND',
		{
			type="not between",
			field: "city",
			arrValue:[8, 9]
		}
			
	]
];
// Valid types are =, <>, <, <=, >, >=, between, not between, like, not like
application.zcore.siteOptionCom.searchSiteOptionGroup("groupName", ts, 0, false);
 --->
<cffunction name="searchSiteOptionGroup" access="public" output="no" returntype="struct" localmode="modern">
	<cfargument name="groupName" type="string" required="yes">
	<cfargument name="arrSearch" type="array" required="yes">
	<cfargument name="parentGroupId" type="string" required="yes">
	<cfargument name="showUnapproved" type="boolean" required="no" default="#false#">
	<cfargument name="offset" type="string" required="no" default="0">
	<cfargument name="limit" type="string" required="no" default="10">
	<cfargument name="orderBy" type="string" required="no" default="">
	<cfargument name="orderByDataType" type="string" required="no" default="">
	<cfargument name="orderByDirection" type="string" required="no" default="">
	<cfargument name="getCount" type="boolean" required="no" default="#false#">
	<cfscript>
	db=request.zos.queryObject;
	rs={count:0, arrResult:[], hasMoreRecords:false};
	arguments.offset=application.zcore.functions.zso(arguments, 'offset', true, 0);
	arguments.limit=application.zcore.functions.zso(arguments, 'limit', true, 10); 
	t9=getTypeData(request.zos.globals.id);
	currentOffset=0;
	if(arguments.orderBy NEQ ""){
		if(arguments.orderByDataType EQ ""){
			arguments.orderByDataType="text";
		}
		if(arguments.orderByDataType NEQ "text" and arguments.orderByDataType NEQ "numeric"){
			throw("Invalid value for arguments.orderByDataType, ""#arguments.orderByDataType#"".");
		}
		if(arguments.orderByDirection EQ ""){
			arguments.orderByDirection="asc";
		}
		if(arguments.orderByDirection NEQ "asc" and arguments.orderByDirection NEQ "desc"){
			throw("Invalid value for arguments.orderByDirection, ""#arguments.orderByDirection#"".");
		}
	}
	if(structkeyexists(t9, "siteOptionGroupIdLookup") and structkeyexists(t9.siteOptionGroupIdLookup, arguments.parentGroupId&chr(9)&arguments.groupName)){
		siteOptionGroupId=t9.siteOptionGroupIdLookup[arguments.parentGroupId&chr(9)&arguments.groupName];
		var groupStruct=t9.siteOptionGroupLookup[siteOptionGroupId];
		if(groupStruct.site_option_group_enable_cache EQ 1){
			arrGroup=application.zcore.functions.zSiteOptionGroupStruct(arguments.groupName);
			if(arguments.orderBy NEQ ""){
				tempStruct={};
				for(i=1;i LTE arrayLen(arrGroup);i++){
					if(arguments.orderByDataType EQ "numeric" and not isnumeric(arrGroup[i][arguments.orderBy])){
						continue;
					}
					tempStruct[i]={
						sortKey: arrGroup[i][arguments.orderBy],
						data:arrGroup[i]
					};
				}

				arrTempKey=structsort(tempStruct, arguments.orderByDataType, arguments.orderByDirection, "sortKey");
				arrGroup2=[];
				for(i=1;i LTE arrayLen(arrTempKey);i++){
					arrayAppend(arrGroup2, tempStruct[arrTempKey[i]].data);
				}
				arrGroup=arrGroup2;
			}
			//writedump(arraylen(arrGroup));
			// return rows in an array.
			//writedump(arguments.arrSearch);
			stopStoring=false;
			rs.count=0;
			for(i=1;i LTE arrayLen(arrGroup);i++){
				row=arrGroup[i];
				if(structkeyexists(row, '__approved') and row.__approved NEQ 1){
					continue;
				}
				match=variables.processSearchArray(arguments.arrSearch, row, groupStruct.site_option_group_id);
				if(match){
					rs.count++;
					if(not stopStoring){
						if(currentOffset LT arguments.offset){
							//echo('skip<br>');
							currentOffset++;
							continue;
						}else{
							//echo('match and store: #arrGroup[i].title#<br />');
							// to avoid having to generate a total count, we just see if there is 1 more matching record.
							if(arguments.getCount){
								arrayAppend(rs.arrResult, arrGroup[i]);
								if(arguments.limit EQ arrayLen(rs.arrResult)){
									stopStoring=true;
								}
							}else{
								if(arguments.limit+1 EQ arrayLen(rs.arrResult)){
									rs.hasMoreRecords=true;
									break;
								}
								arrayAppend(rs.arrResult, arrGroup[i]);
							}
						}
					}
				//}else{
				//	echo('not match: #arrGroup[i].title#<br />');
				}
			}
			//abort;
		}else{
			fieldStruct={};

			sql=variables.processSearchArraySQL(arguments.arrSearch, fieldStruct, 1, groupStruct.site_option_group_id);
			/*if(sql EQ ""){
				return rs;
			}*/
			//writedump(sql);abort;

			groupId=application.zcore.functions.zGetSiteOptionGroupIDWithNameArray([arguments.groupName]);


			arrTable=["site_x_option_group_set s1"];
			arrWhere=["s1.site_id = '#request.zos.globals.id#' and 
			s1.site_x_option_group_set_deleted = 0  and 
			s1.site_option_group_id = '#groupId#' and "&sql];
			arrSelect=[];

			orderTableLookup={};
			fieldIndex=1;
			for(i in fieldStruct){
				tableName="sGroup"&fieldStruct[i];
				orderTableLookup[i]=fieldIndex;
				//arrayAppend(arrSelect, "sVal"&i);
				arrayAppend(arrTable, "site_x_option_group "&tableName);
				arrayAppend(arrWhere, "#tableName#.site_id = s1.site_id and 
				#tableName#.site_x_option_group_set_id = s1.site_x_option_group_set_id and 
				#tableName#.site_option_id = '#application.zcore.functions.zescape(i)#' and 
				#tableName#.site_option_group_id = s1.site_option_group_id AND 
				#tableName#.site_x_option_group_deleted = 0");
				fieldIndex++;
			}
			if(arguments.orderBy NEQ ""){
				// need to lookup the field site_option_id using the site_option_name and groupId
				siteOptionIdLookup=t9.siteOptionIdLookup;
				if(structkeyexists(siteOptionIdLookup, groupId&chr(9)&arguments.orderBy)){
					site_option_id=siteOptionIdLookup[groupId&chr(9)&arguments.orderBy];
					site_option_type_id=t9.siteOptionLookup[site_option_id].type;
					currentCFC=application.zcore.siteOptionCom.getTypeCFC(site_option_type_id);

					arrayAppend(arrSelect, "s2.site_x_option_group_value sVal2");
					arrayAppend(arrTable, "site_x_option_group s2");
					arrayAppend(arrWhere, "s2.site_id = s1.site_id and 
					s2.site_x_option_group_set_id = s1.site_x_option_group_set_id and 
					s2.site_option_id = '#application.zcore.functions.zescape(site_option_id)#' and 
					s2.site_option_group_id = s1.site_option_group_id AND 
					s2.site_x_option_group_deleted = 0");
					fieldIndex++;


					orderByStatement=" ORDER BY "&currentCFC.getSortSQL(2, arguments.orderByDirection);
				}else{
					throw("arguments.orderBy, ""#arguments.orderBy#"" is not a valid field in the site_option_group_id=#groupId# | ""#groupStruct.site_option_group_name#""");
				}
			}else if(structkeyexists(request.zos, 'siteOptionSearchDateRangeSortEnabled')){
				orderByStatement=" ORDER BY s1.site_x_option_group_set_start_date ASC ";
			}else{
				orderByStatement=" ORDER BY s1.site_x_option_group_set_id ASC ";
			}
			db=request.zos.noVerifyQueryObject;
			if(arguments.getCount){
				db.sql="select count(distinct s1.site_x_option_group_set_id) count
				from #arrayToList(arrTable, ", ")# 
				WHERE #arrayToList(arrWhere, " and ")# ";
				if(not arguments.showUnapproved){
					db.sql&=" and site_x_option_group_set_approved=#db.param('1')# ";
				}
				qCount=db.execute("qSelect");  
				rs.count=qCount.count;
				//writedump(qCount);abort;
				if(qCount.recordcount EQ 0 or qCount.count EQ 0){
					return rs;
				} 
			}
			db.sql="select s1.site_x_option_group_set_id ";
			if(arraylen(arrSelect)){
				db.sql&=", "&arrayToList(arrSelect, ", ");
			}
			db.sql&="
			from #arrayToList(arrTable, ", ")# 
			WHERE #arrayToList(arrWhere, " and ")# ";
			if(not arguments.showUnapproved){
				db.sql&=" and site_x_option_group_set_approved=#db.param('1')# ";
			}
			db.sql&=" GROUP BY s1.site_x_option_group_set_id 
			#orderByStatement#
			LIMIT #db.param(arguments.offset)#, #db.param(arguments.limit+1)#";
			qIdList=db.execute("qSelect"); 
			//writedump(qIdList);abort;

			if(qIdList.recordcount EQ 0){
				return rs;
			} 
			arrId=[];
			currentRow=1;
			for(row in qIdList){
				// to avoid having to generate a total count, we just see if there is 1 more matching record.
				if(arguments.limit+1 EQ currentRow){
					rs.hasMoreRecords=true;
					break;
				}
				arrayAppend(arrId, row.site_x_option_group_set_id);
				currentRow++;
			}
			idlist="'"&arraytolist(arrId, "','")&"'";
			
			 db.sql="SELECT *  FROM 
			 #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s1, 
			 #db.table("site_x_option_group", request.zos.zcoreDatasource)# s2
			WHERE  s1.site_id = #db.param(request.zos.globals.id)# and 
			s1.site_x_option_group_set_deleted = #db.param(0)# and 
			s2.site_x_option_group_deleted = #db.param(0)# and 
			s1.site_id = s2.site_id and 
			s1.site_option_group_id = s2.site_option_group_id and 
			s1.site_x_option_group_set_id = s2.site_x_option_group_set_id and ";
			if(not arguments.showUnapproved){
				db.sql&=" s1.site_x_option_group_set_approved=#db.param(1)# and ";
			}
			db.sql&=" s1.site_x_option_group_set_id IN (#db.trustedSQL(idlist)#) ";
			if(qIdList.recordcount GT 1){
				db.sql&="ORDER BY field(s1.site_x_option_group_set_id, #db.trustedSQL(idlist)#)  asc"; 
			}
			qS=db.execute("qS"); 
			//writedump(qS);abort;
			if(qS.recordcount EQ 0){
				return rs;
			}
			lastSetId=0;
			for(row in qS){
				if(lastSetId NEQ row.site_x_option_group_set_id){
					if(lastSetId NEQ 0){
						arrayAppend(rs.arrResult, curStruct);
					}
					curStruct=variables.buildSiteOptionGroupSetId(row);
					lastSetId=row.site_x_option_group_set_id;
				}
				variables.buildSiteOptionGroupSetIdField(row, curStruct);
				
			}
			arrayAppend(rs.arrResult, curStruct);
			return rs;
		}
	}else{
		throw("groupName, ""#arguments.groupName#"" doesn't exist with parentGroupId, ""#arguments.parentGroupId#"".");
	}
	return rs;
	</cfscript>
</cffunction>
 
<!--- 
<cfscript>
ts.startDate=now();
ts.endDate=dateAdd("m", 1, now());
ts.limit=3;
ts.offset=0;
ts.orderBy="startDateASC"; // startDateASC | startDateDESC
arr1=application.zcore.siteOptionCom.siteOptionGroupSetFromDatabaseBySearch(ts, request.zos.globals.id);
</cfscript>
 --->
<cffunction name="siteOptionGroupSetFromDatabaseBySearch" access="public" returntype="array" localmode="modern">
	<cfargument name="searchStruct" type="struct" required="yes">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfscript>
	ts=arguments.searchStruct;
	if(not structkeyexists(ts, 'arrGroupName')){
		throw("arguments.searchStruct.arrGroupName is required. It must be an array of site_option_group_name values.");
	}
	db=request.zos.queryObject;//  SEPARATOR #db.param("','")#) idlist
	 db.sql="SELECT site_x_option_group_set_id FROM 
	 #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s1
	WHERE 
	s1.site_x_option_group_set_deleted = #db.param(0)# and 
	";
	var groupId=application.zcore.functions.zGetSiteOptionGroupIdWithNameArray(ts.arrGroupName, arguments.site_id);
	db.sql&="s1.site_option_group_id = #db.param(groupId)# and ";
	if(structkeyexists(ts, 'endDate')){
		if(structkeyexists(ts, 'startDate')){
			db.sql&=" s1.site_x_option_group_set_start_date <= #db.param(dateformat(ts.endDate, 'yyyy-mm-dd'))# and 
			s1.site_x_option_group_set_end_date >= #db.param(dateformat(ts.startDate, 'yyyy-mm-dd'))#  and ";
		}else{
			db.sql&=" s1.site_x_option_group_set_end_date <= #db.param(dateformat(ts.endDate, 'yyyy-mm-dd'))# and ";
		}
	}else if(structkeyexists(ts, 'startDate')){
		db.sql&=" s1.site_x_option_group_set_start_date >= #db.param(dateformat(ts.startDate, 'yyyy-mm-dd'))# and ";
	}
	if(structkeyexists(ts, 'excludeBeforeStartDate')){
		db.sql&=" s1.site_x_option_group_set_start_date >= #db.param(dateformat(ts.excludeBeforeStartDate, "yyyy-mm-dd")&" 00:00:00")# and ";
	}
	db.sql&="  s1.site_id = #db.param(arguments.site_id)# and  
	s1.site_x_option_group_set_approved=#db.param(1)# ";
	if(structkeyexists(ts, 'orderBy')){
		if(ts.orderBy EQ "startDateASC"){
			db.sql&="ORDER BY site_x_option_group_set_start_date ASC";
		}else if(ts.orderBy EQ "startDateDESC"){
			db.sql&="ORDER BY site_x_option_group_set_start_date DESC";
		}else{
			db.sql&="ORDER BY s1.site_x_option_group_set_sort asc";
		}
	}else{
		db.sql&="ORDER BY s1.site_x_option_group_set_sort asc";
	}
	if(structkeyexists(ts, 'limit')){
		if(ts.limit LT 1){
			application.zcore.functions.z404("Limit can't be less then one.");
		}
		if(structkeyexists(ts, 'offset')){
			if(ts.offset LT 0){
				application.zcore.functions.z404("Offset can't be less then zero.");
			}
			db.sql&=" LIMIT #db.param(ts.offset)#, #db.param(ts.limit)#";
		}else{
			db.sql&=" LIMIT 0, #db.param(ts.limit)#";
		}
	}
	qIdList=db.execute("qIdList");  
	//writedump(qidlist);abort;
	arrRow=[];
	if(qIdList.recordcount EQ 0){
		return arrRow;
	}
	arrId=[];
	for(row in qIdList){
		arrayAppend(arrId, row.site_x_option_group_set_id);
	}
	idlist="'"&arraytolist(arrId, "','")&"'";
	
	 db.sql="SELECT * FROM 
	 #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s1, 
	 #db.table("site_x_option_group", request.zos.zcoreDatasource)# s2
	WHERE  s1.site_id = #db.param(arguments.site_id)# and 
	s1.site_x_option_group_set_deleted = #db.param(0)# and 
	s2.site_x_option_group_deleted = #db.param(0)# and 
	s1.site_id = s2.site_id and 
	s1.site_option_group_id = s2.site_option_group_id and 
	s1.site_x_option_group_set_id = s2.site_x_option_group_set_id and 
	s1.site_x_option_group_set_approved=#db.param(1)# and 
	s1.site_x_option_group_set_id IN (#db.trustedSQL(idlist)#) ";
	if(qIdList.recordcount GT 1){
		db.sql&="ORDER BY field(s1.site_x_option_group_set_id, #db.trustedSQL(idlist)#)  asc"; 
	}
	qS=db.execute("qS"); 
	if(qS.recordcount EQ 0){
		return arrRow;
	}
	lastSetId=0;
	for(row in qS){
		if(lastSetId NEQ row.site_x_option_group_set_id){
			if(lastSetId NEQ 0){
				arrayAppend(arrRow, curStruct);
			}
			curStruct=variables.buildSiteOptionGroupSetId(row);
			lastSetId=row.site_x_option_group_set_id;
		}
		variables.buildSiteOptionGroupSetIdField(row, curStruct);
		
	}
	arrayAppend(arrRow, curStruct);
	return arrRow;
	</cfscript>
</cffunction>

<cffunction name="getSiteOptionGroupById" access="public" returntype="struct" localmode="modern">
	<cfargument name="site_option_group_id" type="string" required="yes">
	<cfscript>
	t9=getTypeData(request.zos.globals.id);
	if(structkeyexists(t9.siteOptionGroupLookup, arguments.site_option_group_id)){
		return t9.siteOptionGroupLookup[arguments.site_option_group_id];
	}else{
		return {};
	}
	</cfscript>
</cffunction>

<cffunction name="getSiteOptionGroupNameById" access="public" returntype="string" localmode="modern">
	<cfargument name="site_option_group_id" type="string" required="yes">
	<cfscript>
	t9=getTypeData(request.zos.globals.id);
	if(structkeyexists(t9.siteOptionGroupLookup, arguments.site_option_group_id)){
		return t9.siteOptionGroupLookup[arguments.site_option_group_id].site_option_group_name;
	}else{
		return "";
	}
	</cfscript>
</cffunction>

<cffunction name="getSiteOptionFieldById" access="public" returntype="struct" localmode="modern">
	<cfargument name="site_option_id" type="string" required="yes">
	<cfscript>
	t9=getTypeData(request.zos.globals.id);
	if(structkeyexists(t9.siteOptionLookup, arguments.site_option_id)){
		return t9.siteOptionLookup[arguments.site_option_id];
	}else{
		return {};
	}
	</cfscript>
</cffunction>


<cffunction name="displaySectionNav" localmode="modern" access="remote" roles="member">
	<cfscript>
	struct=application.zcore.functions.zGetSiteOptionGroupSetById(form.site_x_option_group_set_id);
	if(structcount(struct) EQ 0){
		return;
		// application.zcore.functions.z404("This set record doesn't exist, ""#form.site_x_option_group_set_id#""."); 
	}else{
		groupStruct=application.zcore.functions.zGetSiteOptionGroupById(struct.__groupId);
	}
	curGroupId=groupStruct.site_option_group_id;
	curParentId=groupStruct.site_option_group_parent_id;
	curParentSetId=struct.__parentId;

	/*echo('<p><a href="/z/admin/site-options/manageGroup?site_option_group_id=#groupStruct.site_option_group_id#&amp;site_x_option_group_set_parent_id=#struct.__parentId#">#groupStruct.site_option_group_name#</a> /');*/
	getSetParentLinks(curGroupId, curParentId, curParentSetId, true);
	//echo('</p>');
	echo('<h2>Manage Section: #groupStruct.site_option_group_name# | #struct.__title#</h2>');
	</cfscript>
	
</cffunction>

<cffunction name="getSetParentLinks" access="public" localmode="modern">
	<cfargument name="site_option_group_id" type="string" required="yes">
	<cfargument name="site_option_group_parent_id" type="string" required="yes">
	<cfargument name="site_x_option_group_set_parent_id" type="string" required="yes">
	<cfargument name="linkCurrentPage" type="boolean" required="yes">
	<cfscript>
	db=request.zos.queryObject;
	arrParent=arraynew(1);
	curGroupId=arguments.site_option_group_id;
	curParentId=arguments.site_option_group_parent_id;
	curParentSetId=arguments.site_x_option_group_set_parent_id;
	groupStruct=application.zcore.functions.zGetSiteOptionGroupById(curGroupId);
	if(arguments.linkCurrentPage){
		if(form.method NEQ "sectionGroup"){
			arrayAppend(arrParent, '<a href="/z/admin/site-options/sectionGroup?site_x_option_group_set_id=#form.site_x_option_group_set_id#">Manage Section</a> /');
		}
		arrayAppend(arrParent, '<a href="/z/admin/site-options/manageGroup?site_option_group_id=#curGroupId#&amp;site_x_option_group_set_parent_id=#curParentSetId#">Manage #groupStruct.site_option_group_name#(s)</a> / ');
	}
	if(curParentSetId NEQ 0){
		loop from="1" to="25" index="i"{
			db.sql="select s1.*, s2.site_x_option_group_set_title, s2.site_x_option_group_set_id d2, s2.site_x_option_group_set_parent_id d3 
			from #db.table("site_option_group", request.zos.zcoreDatasource)# s1, 
			#db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s2
			where s1.site_id = s2.site_id and 
			s1.site_option_group_deleted = #db.param(0)# and 
			s2.site_x_option_group_set_deleted = #db.param(0)# and 
			s1.site_id = #db.param(request.zos.globals.id)# and 
			s1.site_option_group_id=s2.site_option_group_id and 
			s2.site_x_option_group_set_id=#db.param(curParentSetId)# and 
			s1.site_option_group_id = #db.param(curParentId)# 
			LIMIT #db.param(0)#,#db.param(1)#";
			q12=db.execute("q12");
			loop query="q12"{
				out='<a href="#application.zcore.functions.zURLAppend("/z/admin/site-options/manageGroup", "site_option_group_id=#q12.site_option_group_id#&amp;site_x_option_group_set_parent_id=#q12.d3#")#">#application.zcore.functions.zFirstLetterCaps(q12.site_option_group_display_name)#</a> / ';
				if(not arguments.linkCurrentPage and curGroupID EQ arguments.site_option_group_id){
					out&=q12.site_x_option_group_set_title&' /';
				}else{
					out&='<a href="/z/admin/site-options/manageGroup?site_option_group_id=#curGroupId#&amp;site_x_option_group_set_parent_id=#q12.d2#">#q12.site_x_option_group_set_title#</a> /';
				}
				arrayappend(arrParent, out);
				curGroupId=q12.site_option_group_id;
				curParentId=q12.site_option_group_parent_id;
				curParentSetId=q12.d3;
			}
			if(q12.recordcount EQ 0 or curParentSetId EQ 0){
				break;
			}
		}
	}
	if(arraylen(arrParent)){
		writeoutput('<p>');
		for(i = arrayLen(arrParent);i GTE 1;i--){
			writeOutput(arrParent[i]&' ');
		}
		writeoutput(" </p>");
	}
	</cfscript>
</cffunction>
<cffunction name="setIdHiddenField" access="public" returntype="any" localmode="modern">
	<cfscript>
    ts3=structnew();
    ts3.name="site_x_option_group_set_id";
    application.zcore.functions.zinput_hidden(ts3);
	</cfscript>
</cffunction>

<cffunction name="requireSectionEnabledSetId" access="public" returntype="any" localmode="modern">
	<cfscript>
	form.site_x_option_group_set_id=application.zcore.functions.zso(form, 'site_x_option_group_set_id', true, 0);
	if(not isSectionEnabledForSetId(form.site_x_option_group_set_id)){
		application.zcore.functions.z404("form.site_x_option_group_set_id, ""#form.site_x_option_group_set_id#"", doesn't exist or doesn't has enable section set to use for the site_option_group.");
	}
	</cfscript>
</cffunction>

<cffunction name="isSectionEnabledForSetId" access="public" returntype="boolean" localmode="modern">
	<cfargument name="site_x_option_group_set_id" type="string" required="yes">
	<cfscript>
	if(arguments.site_x_option_group_set_id EQ "" or arguments.site_x_option_group_set_id EQ 0){
		return true;
	}
	struct=application.zcore.functions.zGetSiteOptionGroupSetById(arguments.site_x_option_group_set_id);
	if(structcount(struct) EQ 0){
		return false;
	}else{
		groupStruct=application.zcore.functions.zGetSiteOptionGroupById(struct.__groupId);
		if(groupStruct.site_option_group_enable_section EQ 1){
			return true;
		}else{
			return false;
		}
	}
	</cfscript>
</cffunction>

<cffunction name="getSiteOptionFieldNameById" access="public" returntype="string" localmode="modern">
	<cfargument name="site_option_id" type="string" required="yes">
	<cfscript>
	t9=getTypeData(request.zos.globals.id);
	if(structkeyexists(t9.siteOptionLookup, arguments.site_option_id)){
		return t9.siteOptionLookup[arguments.site_option_id].site_option_name;
	}else{
		return "";
	}
	</cfscript>
</cffunction>


<cffunction name="siteOptionGroupSetCountFromDatabaseBySearch" access="public" returntype="numeric" localmode="modern">
	<cfargument name="searchStruct" type="struct" required="yes">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfscript>
	ts=arguments.searchStruct;
	if(not structkeyexists(ts, 'arrGroupName')){
		throw("arguments.searchStruct.arrGroupName is required. It must be an array of site_option_group_name values.");
	}
	db=request.zos.queryObject;//  SEPARATOR #db.param("','")#) idlist
	 db.sql="SELECT count(site_x_option_group_set_id) count FROM 
	 #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s1
	WHERE s1.site_x_option_group_set_deleted = #db.param(0)# and ";
	var groupId=application.zcore.functions.zGetSiteOptionGroupIdWithNameArray(ts.arrGroupName, arguments.site_id);
	db.sql&="s1.site_option_group_id = #db.param(groupId)# and ";
	if(structkeyexists(ts, 'endDate')){
		if(structkeyexists(ts, 'startDate')){
			db.sql&=" s1.site_x_option_group_set_start_date <= #db.param(dateformat(ts.endDate, 'yyyy-mm-dd'))# and 
			s1.site_x_option_group_set_end_date >= #db.param(dateformat(ts.startDate, 'yyyy-mm-dd'))#  and ";
		}else{
			db.sql&=" s1.site_x_option_group_set_end_date <= #db.param(dateformat(ts.endDate, 'yyyy-mm-dd'))# and ";
		}
	}else if(structkeyexists(ts, 'startDate')){
		db.sql&=" s1.site_x_option_group_set_start_date >= #db.param(dateformat(ts.startDate, 'yyyy-mm-dd'))# and ";
	}
	db.sql&="  s1.site_id = #db.param(arguments.site_id)# and  
	s1.site_x_option_group_set_approved=#db.param(1)# ";
	qIdList=db.execute("qIdList");  
	if(qIdList.recordcount EQ 0){
		return 0;
	}else{
		return qIdList.count;
	}
	</cfscript>
</cffunction>
 
<cffunction name="siteOptionGroupSetFromDatabaseBySetId" access="public" returntype="struct" localmode="modern">
	<cfargument name="setId" type="string" required="yes">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfargument name="showUnapproved" type="boolean" required="no" default="#false#">
	<cfscript>
	db=request.zos.queryObject;
	 db.sql="SELECT * FROM 
	 #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s1, 
	 #db.table("site_x_option_group", request.zos.zcoreDatasource)# s2
	WHERE s1.site_id = #db.param(arguments.site_id)# and 
	s1.site_x_option_group_set_deleted = #db.param(0)# and 
	s2.site_x_option_group_deleted = #db.param(0)# and 
	s1.site_id = s2.site_id and 
	s1.site_option_group_id = s2.site_option_group_id and 
	s1.site_x_option_group_set_id = s2.site_x_option_group_set_id and ";
	if(not arguments.showUnapproved){
		db.sql&=" s1.site_x_option_group_set_approved=#db.param(1)# and ";
	}
	db.sql&=" s1.site_x_option_group_set_id = #db.param(arguments.setId)# 
	ORDER BY s1.site_x_option_group_set_sort asc";
	qS=db.execute("qS"); 
	resultStruct={};
	lastSetId=0;
	for(row in qS){
		if(lastSetId NEQ row.site_x_option_group_set_id){
			resultStruct=variables.buildSiteOptionGroupSetId(row);
			lastSetId=row.site_x_option_group_set_id;
		}
		variables.buildSiteOptionGroupSetIdField(row, resultStruct);
		
	}
	return resultStruct;
	</cfscript>
</cffunction>


<cffunction name="siteOptionGroupSetFromDatabaseBySortedArray" access="public" returntype="array" localmode="modern">
	<cfargument name="arrSetId" type="array" required="yes">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfscript>
	db=request.zos.queryObject;
	for(i=1;i LTE arraylen(arguments.arrSetId);i++){
		arguments.arrSetId[i]=application.zcore.functions.zescape(arguments.arrSetId[i]);
	} 
	idList="'"&arrayToList(arguments.arrSetId, "','")&"'";
	 db.sql="SELECT * FROM 
	 #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s1, 
	 #db.table("site_x_option_group", request.zos.zcoreDatasource)# s2
	WHERE s1.site_id = #db.param(arguments.site_id)# and 
	s1.site_x_option_group_set_deleted = #db.param(0)# and 
	s2.site_x_option_group_deleted = #db.param(0)# and 
	s1.site_id = s2.site_id and 
	s1.site_option_group_id = s2.site_option_group_id and 
	s1.site_x_option_group_set_id = s2.site_x_option_group_set_id and 
	s1.site_x_option_group_set_approved=#db.param(1)# and 
	s1.site_x_option_group_set_id IN (#db.trustedSQL(idList)#) 
	ORDER BY field(s1.site_x_option_group_set_id, #db.trustedSQL(idList)#) ASC";
	qS=db.execute("qS"); 
	arrRow=[];
	if(qS.recordcount EQ 0){
		return arrRow;
	}
	lastSetId=0;
	for(row in qS){
		if(lastSetId NEQ row.site_x_option_group_set_id){
			if(lastSetId NEQ 0){
				arrayAppend(arrRow, curStruct);
			}
			curStruct=variables.buildSiteOptionGroupSetId(row);
			lastSetId=row.site_x_option_group_set_id;
		}
		variables.buildSiteOptionGroupSetIdField(row, curStruct);
		
	}
	arrayAppend(arrRow, curStruct);
	return arrRow;
	</cfscript>
</cffunction>

<cffunction name="siteOptionGroupSetFromDatabaseByGroupId" access="public" localmode="modern">
	<cfargument name="groupId" type="string" required="yes">
	<cfargument name="site_option_app_id" type="numeric" required="yes">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfargument name="parentStruct" type="struct" required="no" default="#{__groupId=0,__setId=0}#">
	<cfscript>
	db=request.zos.queryObject;
	 db.sql="SELECT * FROM 
	 #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s1, 
	 #db.table("site_x_option_group", request.zos.zcoreDatasource)# s2
	WHERE s1.site_id = #db.param(arguments.site_id)# and 
	s1.site_x_option_group_set_deleted = #db.param(0)# and 
	s2.site_x_option_group_deleted = #db.param(0)# and 
	s1.site_id = s2.site_id and 
	s1.site_option_group_id = s2.site_option_group_id and 
	s1.site_option_app_id = #db.param(arguments.site_option_app_id)# and 
	s1.site_x_option_group_set_id = s2.site_x_option_group_set_id and 
	s1.site_x_option_group_set_parent_id = #db.param(arguments.parentStruct.__setId)# and 
	s1.site_x_option_group_set_approved=#db.param(1)# and 
	s1.site_option_group_id = #db.param(arguments.groupId)# 
	ORDER BY s1.site_x_option_group_set_sort asc";
	qS=db.execute("qS"); 
	arrRow=[];
	if(qS.recordcount EQ 0){
		return arrRow;
	}
	lastSetId=0;
	for(row in qS){
		if(lastSetId NEQ row.site_x_option_group_set_id){
			if(lastSetId NEQ 0){
				arrayAppend(arrRow, curStruct);
			}
			curStruct=variables.buildSiteOptionGroupSetId(row);
			lastSetId=row.site_x_option_group_set_id;
		}
		variables.buildSiteOptionGroupSetIdField(row, curStruct);
		
	}
	arrayAppend(arrRow, curStruct);
	return arrRow;
	</cfscript>
</cffunction>
	
<cffunction name="buildSiteOptionGroupSetIdField" access="private" localmode="modern">
	<cfargument name="row" type="struct" required="yes"> 
	<cfargument name="curStruct" type="struct" required="yes"> 
	<cfscript>
	var t9=getTypeData(arguments.row.site_id);
	if(arguments.row.site_option_id NEQ ""){
		typeId=t9.siteOptionLookup[arguments.row.site_option_id].type;
		if(typeId EQ 3 or typeId EQ 9){
			if(arguments.row.site_x_option_group_value NEQ "" and arguments.row.site_x_option_group_value NEQ "0"){
				if(application.zcore.functions.zso(t9.siteOptionLookup[arguments.row.site_option_id].optionStruct, 'file_securepath') EQ "Yes"){
					tempValue="/zuploadsecure/site-options/"&arguments.row.site_x_option_group_value;
				}else{
					tempValue="/zupload/site-options/"&arguments.row.site_x_option_group_value;
				}
			}else{
				tempValue="";
			}
		}else{
			tempValue=arguments.row.site_x_option_group_value;
		}
		arguments.curStruct[t9.siteOptionLookup[arguments.row.site_option_id].name]=tempValue;
	}
	</cfscript>
</cffunction>

<cffunction name="buildSiteOptionGroupSetId" access="private" localmode="modern">
	<cfargument name="row" type="struct" required="yes"> 
	<cfscript>
	row=arguments.row; 
	var t9=getTypeData(row.site_id);
	ts=structnew();
	ts.__sort=row.site_x_option_group_set_sort;
	ts.__setId=row.site_x_option_group_set_id;
	ts.__dateModified=row.site_x_option_group_set_updated_datetime;
	ts.__groupId=row.site_option_group_id;
	ts.__approved=row.site_x_option_group_set_approved;
	ts.__title=row.site_x_option_group_set_title;
	ts.__parentID=row.site_x_option_group_set_parent_id;
	ts.__summary=row.site_x_option_group_set_summary;
	// build url
	if(row.site_x_option_group_set_image_library_id NEQ 0){
		ts.__image_library_id=row.site_x_option_group_set_image_library_id;
	}
	groupStruct=t9.siteOptionGroupLookup[row.site_option_group_id];
	if(groupStruct.site_option_group_enable_unique_url EQ 1){
		if(row.site_x_option_group_set_override_url NEQ ""){
			ts.__url=row.site_x_option_group_set_override_url;
		}else{
			var urlId=application.zcore.functions.zvar('optionGroupURLID', row.site_id);
			if(urlId EQ "" or urlId EQ 0){
				throw("site_option_group_url_id is not set for site_id, #arguments.site_id#.");
			}
			ts.__url="/#application.zcore.functions.zURLEncode(row.site_x_option_group_set_title, '-')#-#urlId#-#row.site_x_option_group_set_id#.html";
		}
	}
	structappend(ts, t9.siteOptionGroupDefaults[row.site_option_group_id]);
	return ts;
	</cfscript>
</cffunction>


<cffunction name="setSiteOptionGroupImportStruct" access="public" localmode="modern">
	<cfargument name="site_option_group_name" type="string" required="yes">
	<cfargument name="site_option_app_id" type="numeric" required="yes">
	<cfargument name="site_option_group_parent_id" type="numeric" required="yes">
	<cfargument name="site_x_option_group_set_parent_id" type="numeric" required="yes">
	<cfargument name="dataStruct" type="struct" required="yes">
	<cfargument name="importStruct" type="struct" required="yes">
	<cfscript>
	if(not structkeyexists(request.zos, 'siteOptionGroupImportTable')){
		request.zos.siteOptionGroupImportTable={};
	}
	form.site_x_option_group_set_id=0;
	form.site_x_option_group_set_parent_id=arguments.site_x_option_group_set_parent_id;
	form.site_option_app_id=arguments.site_option_app_id;
	form.site_option_group_id=application.zcore.functions.zSiteOptionGroupIdByName(arguments.site_option_group_name, arguments.site_option_group_parent_id);

	if(structkeyexists(request.zos.siteOptionGroupImportTable, form.site_option_group_id)){
		ts=request.zos.siteOptionGroupImportTable[form.site_option_group_id];
	}else{
		db=request.zos.queryObject;
		db.sql="select * from #db.table("site_option", request.zos.zcoreDatasource)# WHERE 
		site_option_group_id = #db.param(form.site_option_group_id)# and 
		site_option_type_id <> #db.param(11)# and 
		site_option_deleted = #db.param(0)# and 
		site_id = #db.param(request.zos.globals.id)# ";
		qOption=db.execute("qOption");
		var ts={}; 
		var arrSiteOptionId=[];
		for(row in qOption){
			arrayAppend(arrSiteOptionId, row.site_option_id);
			ts[row.site_option_name]=row.site_option_id;
		} 
		ts.site_option_id=arrayToList(arrSiteOptionId, ",");
		request.zos.siteOptionGroupImportTable[form.site_option_group_id]=ts;
	}
	arguments.importStruct.site_option_id=ts.site_option_id;
	for(i in arguments.dataStruct){
		if(structkeyexists(ts, i)){
			arguments.importStruct['newvalue'&ts[i]]=arguments.dataStruct[i];
		}
	}
	</cfscript>
</cffunction>
 
<cffunction name="deleteSiteOptionGroupSetIdCache" localmode="modern" access="public">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfargument name="site_x_option_group_set_id" type="numeric" required="yes"> 
	<cfscript>
	variables.deleteSiteOptionGroupSetIdCacheInternal(arguments.site_id, arguments.site_x_option_group_set_id, false);
	application.zcore.functions.zCacheJsonSiteAndUserGroup(arguments.site_id, application.zcore.siteGlobals[arguments.site_id]);
	</cfscript>
</cffunction>

<cffunction name="deleteSiteOptionGroupSetIdCacheInternal" localmode="modern" access="private">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfargument name="site_x_option_group_set_id" type="numeric" required="yes">
	<cfargument name="disableFileUpdate" type="boolean" required="yes">
	<cfscript>
	var row=0;
	var tempValue=0; 
	t9=getSiteData(arguments.site_id);
	var db=request.zos.queryObject; 
	// remove only the keys I need to and then publish  
	if(not structkeyexists(t9.siteOptionGroupSetId, arguments.site_x_option_group_set_id&"_groupId")){
		return;
	}
	var groupId=t9.siteOptionGroupSetId[arguments.site_x_option_group_set_id&"_groupId"];
	var appId=t9.siteOptionGroupSetId[arguments.site_x_option_group_set_id&"_appId"];
	var parentId=t9.siteOptionGroupSetId[arguments.site_x_option_group_set_id&"_parentId"]; 
	var arrChild=t9.siteOptionGroupSetId[parentId&"_childGroup"][groupId]; 
	deleteIndex=0;
	for(var i=1;i LTE arrayLen(arrChild);i++){
		if(arguments.site_x_option_group_set_id EQ arrChild[i]){
			deleteIndex=1;
			break;
		}
	}
	var arrChild2=t9.siteOptionGroupSetArrays[appId&chr(9)&groupId&chr(9)&parentId];
	deleteIndex2=0;
	for(var i=1;i LTE arrayLen(arrChild2);i++){
		if(arguments.site_x_option_group_set_id EQ arrChild2[i].__setId){
			deleteIndex2=i;
		}
	}
	// recursively delete children from shared memory cache
	var childGroup=duplicate(t9.siteOptionGroupSetId[arguments.site_x_option_group_set_id&"_childGroup"]); 
	for(var f in childGroup){
		for(var g=1;g LTE arraylen(childGroup[f]);g++){ 
			this.deleteSiteOptionGroupSetIdCacheInternal(arguments.site_id, childGroup[f][g], true);
		}
	}
	for(var n in t9.siteOptionGroupFieldLookup[groupId]){ 
		structdelete(t9.siteOptionGroupSetId, arguments.site_x_option_group_set_id&"_f"&n);
	}
	if(deleteIndex){
		arrayDeleteAt(arrChild, deleteIndex);
	}
	if(deleteIndex2){
		arrayDeleteAt(arrChild2, deleteIndex2);
	} 
	structdelete(t9.siteOptionGroupSet, arguments.site_x_option_group_set_id);
	structdelete(t9.siteOptionGroupSetId, arguments.site_x_option_group_set_id&"_groupId");
	structdelete(t9.siteOptionGroupSetId, arguments.site_x_option_group_set_id&"_appId");
	structdelete(t9.siteOptionGroupSetId, arguments.site_x_option_group_set_id&"_parentId");
	structdelete(t9.siteOptionGroupSetId, arguments.site_x_option_group_set_id&"_childGroup"); 

	</cfscript>
</cffunction>


<!--- <cffunction name="updateSiteOptionGroupIdCache" localmode="modern" access="public">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfargument name="site_option_group_id" type="numeric" required="yes">
	<cfscript>
	var db=request.zos.queryObject;
	db.sql="select * from #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# WHERE 
	site_option_group_id = #db.param(arguments.site_option_group_id)# and 
	site_id = #db.param(arguments.site_id)# and 
	site_x_option_group_set_deleted = #db.param(0)# 
	";
	qSet=db.execute("qSet");
	for(row in qSet){
		updateSiteOptionGroupSetIdCache(row.site_id, row.site_x_option_group_set_id);
	}
	</cfscript>
</cffunction> --->


<cffunction name="resortSiteOptionGroupSets" localmode="modern" access="public">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfargument name="site_option_app_id" type="numeric" required="yes">
	<cfargument name="site_option_group_id" type="numeric" required="yes">
	<cfargument name="site_x_option_group_set_parent_id" type="numeric" required="yes">
	<cfscript>
	var db=request.zos.queryObject;
	db.sql="select site_x_option_group_set_id from #db.table("site_x_option_group_set", request.zos.zcoreDatasource)#
	WHERE 
	site_x_option_group_set_deleted = #db.param(0)# and 
	site_x_option_group_set_parent_id= #db.param(arguments.site_x_option_group_set_parent_id)# and 
	site_option_group_id = #db.param(arguments.site_option_group_id)# and 
	site_option_app_id = #db.param(arguments.site_option_app_id)# and 
	site_id = #db.param(arguments.site_id)# 
	ORDER BY site_x_option_group_set_sort";
	var qSort=db.execute("qSort");
	var arrTemp=[];
	sortStruct={};
	i=1;
	for(var row2 in qSort){
		arrayAppend(arrTemp, row2.site_x_option_group_set_id);
		sortStruct[row2.site_x_option_group_set_id]=i;
		i++;
	}
	t9=getSiteData(arguments.site_id);
	t9.siteOptionGroupSetId[arguments.site_x_option_group_set_parent_id&"_childGroup"][arguments.site_option_group_id]=arrTemp;

	arrData=t9.siteOptionGroupSetArrays[arguments.site_option_app_id&chr(9)&arguments.site_option_group_id&chr(9)&arguments.site_x_option_group_set_parent_id];
	arrDataNew=[];
	for(i=1;i LTE arraylen(arrData);i++){
		sortIndex=sortStruct[arrData[i].__setId];
		arrDataNew[sortIndex]=arrData[i];
	}
	t9.siteOptionGroupSetArrays[arguments.site_option_app_id&chr(9)&arguments.site_option_group_id&chr(9)&arguments.site_x_option_group_set_parent_id]=arrDataNew;
	</cfscript>
</cffunction>
	
<cffunction name="updateSiteOptionGroupSetIdCache" localmode="modern" access="public">
	<cfargument name="site_id" type="numeric" required="yes">
	<cfargument name="site_x_option_group_set_id" type="numeric" required="yes">
	<cfscript>
	var row=0;
	var tempValue=0;
	var db=request.zos.queryObject;
	var debug=false;
	var startTime=gettickcount();
	/* if(request.zos.isdeveloper){
		 debug=true;
	 }*/

	t9=getSiteData(arguments.site_id);
	typeStruct=getTypeData(arguments.site_id);
	db.sql="SELECT s1.*, s3.site_option_id groupSetOptionId, s4.site_option_type_id typeId, s3.site_x_option_group_value groupSetValue, s3.site_x_option_group_original groupSetOriginal  
	FROM #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s1  
	LEFT JOIN #db.table("site_x_option_group", request.zos.zcoreDatasource)# s3  ON 
	s1.site_option_group_id = s3.site_option_group_id AND 
	s1.site_x_option_group_set_id = s3.site_x_option_group_set_id and 
	s1.site_id = s3.site_id
	LEFT JOIN #db.table("site_option", request.zos.zcoreDatasource)# s4 ON 
	s4.site_option_group_id = s3.site_option_group_id and 
	s4.site_option_id = s3.site_option_id and 
	s4.site_id = s3.site_id 
	WHERE s1.site_id = #db.param(arguments.site_id)#  and 
	s1.site_x_option_group_set_deleted = #db.param(0)# and 
	s3.site_x_option_group_deleted = #db.param(0)# and 
	s4.site_option_deleted = #db.param(0)# and 
	s1.site_x_option_group_set_approved=#db.param(1)# and 
	s1.site_x_option_group_set_id=#db.param(arguments.site_x_option_group_set_id)#
	ORDER BY s1.site_x_option_group_set_parent_id ASC, s1.site_x_option_group_set_sort ASC ";
	//if(debug) writedump(db.sql);
	var qS=db.execute("qS"); 
	if(debug) writedump(qS);
	var tempUniqueStruct=structnew();
	if(debug) writeoutput(((gettickcount()-startTime)/1000)& 'seconds1-1<br>'); startTime=gettickcount();
	var newRecord=false;
	for(row in qS){
		var id=row.site_x_option_group_set_id;
		if(structkeyexists(t9.siteOptionGroupSetId, id&"_appId") EQ false){
			newRecord=true;
			typeStruct.siteOptionGroupLookup[row.site_option_group_id].count++;
			t9.siteOptionGroupSetId[id&"_groupId"]=row.site_option_group_id;
			t9.siteOptionGroupSetId[id&"_appId"]=row.site_option_app_id;
			t9.siteOptionGroupSetId[id&"_parentId"]=row.site_x_option_group_set_parent_id;
			t9.siteOptionGroupSetId[id&"_childGroup"]=structnew();
		}
		if(structkeyexists(t9.siteOptionGroupSetId, row.site_x_option_group_set_parent_id&"_childGroup")){
			if(structkeyexists(t9.siteOptionGroupSetId[row.site_x_option_group_set_parent_id&"_childGroup"], row.site_option_group_id) EQ false){
				t9.siteOptionGroupSetId[row.site_x_option_group_set_parent_id&"_childGroup"][row.site_option_group_id]=arraynew(1);
			}
			if(typeStruct.siteOptionGroupLookup[row.site_option_group_id].site_option_group_enable_sorting EQ 1){
				if(structkeyexists(tempUniqueStruct, row.site_x_option_group_set_parent_id&"_"&id) EQ false){
					var arrChild=t9.siteOptionGroupSetId[row.site_x_option_group_set_parent_id&"_childGroup"][row.site_option_group_id];
					var resort=false;
					if(arrayLen(arrChild) LT row.site_x_option_group_set_sort){
						resort=true;
					}else if(arrayLen(arrChild) GTE row.site_x_option_group_set_sort){
						if(arrChild[row.site_x_option_group_set_sort] NEQ id){
							resort=true;
						}
					/*}else if(arrayLen(arrChild)+1 EQ row.site_x_option_group_set_sort){
						arrayAppend(arrChild, id);*/
					}else{
						resort=true;
					} 
			//writedump(resort);
					if(resort){
						db.sql="select site_x_option_group_set_id from #db.table("site_x_option_group_set", request.zos.zcoreDatasource)#
						WHERE 
						site_x_option_group_set_deleted = #db.param(0)# and 
						site_x_option_group_set_parent_id= #db.param(row.site_x_option_group_set_parent_id)# and 
						site_option_group_id = #db.param(row.site_option_group_id)# and 
						site_option_app_id = #db.param(row.site_option_app_id)# and 
						site_id = #db.param(arguments.site_id)# 
						ORDER BY site_x_option_group_set_sort";
						var qSort=db.execute("qSort");
						var arrTemp=[];
						for(var row2 in qSort){
							arrayAppend(arrTemp, row2.site_x_option_group_set_id);
						}
						t9.siteOptionGroupSetId[row.site_x_option_group_set_parent_id&"_childGroup"][row.site_option_group_id]=arrTemp;
					}
					//writedump(t9.siteOptionGroupSetId[row.site_x_option_group_set_parent_id&"_childGroup"][row.site_option_group_id]);
					tempUniqueStruct[row.site_x_option_group_set_parent_id&"_"&id]=true;
				}
			}else if(newRecord){
				var arrChild=t9.siteOptionGroupSetId[row.site_x_option_group_set_parent_id&"_childGroup"][row.site_option_group_id];
				var found=false;
				for(var i=1;i LTE arrayLen(arrChild);i++){
					if(row.site_x_option_group_set_id EQ arrChild[i]){
						found=true;
						break;
					}
				}
				if(not found){
					arrayAppend(arrChild, row.site_x_option_group_set_id);
				}
			}
		}
		if(row.typeId EQ 3 or row.typeId EQ 9){
			if(row.groupSetValue NEQ "" and row.groupSetValue NEQ "0"){
				optionStruct=typeStruct.siteOptionLookup[row.groupSetOptionId].optionStruct;
				if(application.zcore.functions.zso(optionStruct, 'file_securepath') EQ "Yes"){
					tempValue="/zuploadsecure/site-options/"&row.groupSetValue;
				}else{
					tempValue="/zupload/site-options/"&row.groupSetValue;
				}
			}else{
				tempValue="";
			}
		}else{
			tempValue=row.groupSetValue;
		}
		t9.siteOptionGroupSetId[id&"_f"&row.groupSetOptionId]=tempValue;
		if(row.typeId EQ 3){
			if(row.groupSetOriginal NEQ ""){
				t9.siteOptionGroupSetId["__original "&id&"_f"&row.groupSetOptionId]="/zupload/site-options/"&row.groupSetOriginal;
			}else{
				t9.siteOptionGroupSetId["__original "&id&"_f"&row.groupSetOptionId]=tempValue;
			}
		} 
	}
	if(debug) writeoutput(((gettickcount()-startTime)/1000)& 'seconds1-2<br>'); startTime=gettickcount();
	 db.sql="SELECT * FROM 
	 #db.table("site_x_option_group_set", request.zos.zcoreDatasource)# s1, 
	 #db.table("site_option_group", request.zos.zcoreDatasource)# s2
	WHERE s1.site_id = #db.param(arguments.site_id)# and 
	s1.site_x_option_group_set_deleted = #db.param(0)# and 
	s2.site_option_group_deleted = #db.param(0)# and 
	s1.site_id = s2.site_id and 
	s1.site_option_group_id = s2.site_option_group_id and 
	s1.site_x_option_group_set_id = #db.param(arguments.site_x_option_group_set_id)# 
	ORDER BY s1.site_x_option_group_set_sort asc";
	var qS=db.execute("qS"); 
	if(debug) writeoutput(((gettickcount()-startTime)/1000)& 'seconds1-3<br>'); startTime=gettickcount();
	if(debug) writedump(qS);
	for(row in qS){
		if(structkeyexists(t9.siteOptionGroupSetArrays, row.site_option_app_id&chr(9)&row.site_option_group_id&chr(9)&row.site_x_option_group_set_parent_id) EQ false){
			t9.siteOptionGroupSetArrays[row.site_option_app_id&chr(9)&row.site_option_group_id&chr(9)&row.site_x_option_group_set_parent_id]=arraynew(1);
		}
		var ts=structnew();
		ts.__setId=row.site_x_option_group_set_id;
		ts.__dateModified=row.site_x_option_group_set_updated_datetime;
		ts.__groupId=row.site_option_group_id;
		ts.__approved=row.site_x_option_group_set_approved;
		ts.__title=row.site_x_option_group_set_title;
		ts.__parentID=row.site_x_option_group_set_parent_id;
		ts.__summary=row.site_x_option_group_set_summary;
		// build url
		if(row.site_x_option_group_set_image_library_id NEQ 0){
			ts.__image_library_id=row.site_x_option_group_set_image_library_id;
		}
		if(row.site_option_group_enable_unique_url EQ 1){
			if(row.site_x_option_group_set_override_url NEQ ""){
				ts.__url=row.site_x_option_group_set_override_url;
			}else{
				var urlId=application.zcore.functions.zvar('optionGroupUrlID', arguments.site_id);
				if(urlId EQ "" or urlId EQ 0){
					throw("site_option_group_url_id is not set for site_id, #arguments.site_id#.");
				}
				ts.__url="/#application.zcore.functions.zURLEncode(row.site_x_option_group_set_title, '-')#-#urlId#-#row.site_x_option_group_set_id#.html";
			}
		} 
		var fieldStruct=t9.siteOptionGroupFieldLookup[ts.__groupId];
		
		var defaultStruct=t9.siteOptionGroupDefaults[row.site_option_group_id];
		for(var i2 in fieldStruct){
			var cf=t9.siteOptionLookup[i2];
			if(structkeyexists(t9.siteOptionGroupSetId, "__original "&ts.__setId&"_f"&i2)){
				ts["__original "&cf.name]=t9.siteOptionGroupSetId["__original "&ts.__setId&"_f"&i2];
			}
			if(structkeyexists(t9.siteOptionGroupSetId, ts.__setId&"_f"&i2)){
				ts[cf.name]=t9.siteOptionGroupSetId[ts.__setId&"_f"&i2];
			}else if(structkeyexists(defaultStruct, cf.name)){
				ts[cf.name]=defaultStruct[cf.name];
			}else{
				ts[cf.name]="";
			}
		}
		if(debug) writedump(ts);
		
		t9.siteOptionGroupSet[row.site_x_option_group_set_id]= ts;
		if(typeStruct.siteOptionGroupLookup[row.site_option_group_id].site_option_group_enable_sorting EQ 1){
			var arrChild=t9.siteOptionGroupSetArrays[row.site_option_app_id&chr(9)&ts.__groupId&chr(9)&row.site_x_option_group_set_parent_id];
			var resort=false;
			if(arrayLen(arrChild) GTE row.site_x_option_group_set_sort){
				if(arrayLen(arrChild) LT row.site_x_option_group_set_sort){
					resort=true;
				}else if(arrChild[row.site_x_option_group_set_sort].__setId NEQ row.site_x_option_group_set_id){
					resort=true;
				}else{ 
					arrChild[row.site_x_option_group_set_sort]=ts;
				} 
			}else{
				resort=true;
			} 
			if(resort){
				var arrChild2=t9.siteOptionGroupSetId[row.site_x_option_group_set_parent_id&"_childGroup"][row.site_option_group_id];
				var arrTemp=[]; 
				try{
					for(var i=1;i LTE arraylen(arrChild2);i++){
						arrayAppend(arrTemp, t9.siteOptionGroupSet[arrChild2[i]]);
					}
					t9.siteOptionGroupSetArrays[row.site_option_app_id&chr(9)&ts.__groupId&chr(9)&row.site_x_option_group_set_parent_id]=arrTemp;
				}catch(Any e){
					application.zcore.functions.zOS_cacheSiteAndUserGroups(request.zos.globals.id);
					ts={};
					ts.subject="Site option group update resort failed";
					savecontent variable="output"{
						echo('#application.zcore.functions.zHTMLDoctype()#
						<head>
						<meta charset="utf-8" />
						<title>Error</title>
						</head>
						
						<body>');

						writedump(form);
						writedump(e);
						echo('</body>
						</html>');
					}
					ts.html=output;
					ts.to=request.zos.developerEmailTo;
					ts.from=request.zos.developerEmailFrom;
					rCom=application.zcore.email.send(ts);
					if(rCom.isOK() EQ false){
						rCom.setStatusErrors(request.zsid);
						application.zcore.functions.zstatushandler(request.zsid);
						application.zcore.functions.zabort();
					}
				}
				/*
				// might want to use this someday again
				db.sql="select site_x_option_group_set_id 
				from #db.table("site_x_option_group_set", request.zos.zcoreDatasource)#
				WHERE site_x_option_group_set_id = #db.param(id)# and 
				site_x_option_group_set_deleted = #db.param(0)# and 
				site_id = #db.param(arguments.site_id)# 
				ORDER BY site_x_option_group_set_sort";
				var qSort=db.execute("qSort");
				var arrTemp=[];
				for(var row2 in qSort){
					arrayAppend(arrTemp, t9.siteOptionGroupSet[row2.site_x_option_group_set_id]);
				}
				t9.siteOptionGroupSetArrays[row.site_option_app_id&chr(9)&ts.__groupId&chr(9)&row.site_x_option_group_set_parent_id]=arrTemp;
				*/
			}
		}else{// if(newRecord){
			var arrChild=t9.siteOptionGroupSetArrays[row.site_option_app_id&chr(9)&ts.__groupId&chr(9)&row.site_x_option_group_set_parent_id];//t9.siteOptionGroupSetId[row.site_x_option_group_set_parent_id&"_childGroup"][row.site_option_group_id];
			var found=false;
			for(var i=1;i LTE arrayLen(arrChild);i++){
				if(row.site_x_option_group_set_id EQ arrChild[i].__setID){
					found=true;
					arrChild[i]=ts;
					break;
				}
			}
			//writedump("found:"&found);
			if(not found){
				arrayAppend(arrChild, ts);
			}
		}
	}  
	if(debug and structkeyexists(local, 'arrChild')) writedump(arrChild);
	if(debug) writeoutput(((gettickcount()-startTime)/1000)& 'seconds1-4<br>'); startTime=gettickcount();
	application.zcore.functions.zCacheJsonSiteAndUserGroup(arguments.site_id, application.zcore.siteGlobals[arguments.site_id]); 
	if(debug) writeoutput(((gettickcount()-startTime)/1000)& 'seconds1-5<br>'); startTime=gettickcount();
	if(debug) application.zcore.functions.zabort();
	</cfscript>
</cffunction>
 
 
<cffunction name="getSiteMap" localmode="modern" access="public">
	<cfargument name="arrURL" type="array" required="yes">
	<cfscript>
	var db=request.zos.queryObject;
	var row=0;
	var i=0;
	db.sql="select * from #db.table("site_option_group", request.zos.zcoreDatasource)# 
	where 
	site_option_group_deleted = #db.param(0)# and 
	site_option_group_parent_id = #db.param('0')# and 
	site_id = #db.param(request.zos.globals.id)# and 
	site_option_group_disable_site_map = #db.param(0)# and 
	site_option_group.site_option_group_enable_unique_url = #db.param(1)# ";
	local.qGroup=db.execute("qGroup");
	for(row in local.qGroup){
		local.arr1=application.zcore.functions.zSiteOptionGroupStruct(row.site_option_group_name, 0, row.site_id);
		for(i=1;i LTE arraylen(local.arr1);i++){
			if(local.arr1[i].__approved EQ 1){
				local.t2=StructNew();
				local.t2.groupName=row.site_option_group_display_name;
				local.t2.url=request.zos.currentHostName&local.arr1[i].__url;
				local.t2.title=local.arr1[i].__title;
				arrayappend(arguments.arrUrl,local.t2);
			}
		}
	}
	return arguments.arrURL;
	</cfscript>
</cffunction>

<cffunction name="searchReindex" localmode="modern" access="public" hint="Reindex ALL site-option records in the entire app.">
	<cfscript>
	var db=request.zos.queryObject;
	var row=0;
	var offset=0;
	var limit=30;
	setting requesttimeout="5000";
	startDatetime=dateformat(now(), "yyyy-mm-dd")&" "&timeformat(now(), "HH:mm:ss");
	db.sql="select site_option_group_id, site_option_group_parent_id, site_option_group_name, site_id FROM
	#db.table("site_option_group", request.zos.zcoreDatasource)# site_option_group WHERE 
	site_id <> #db.param(-1)# and 
	site_option_group_deleted = #db.param(0)# 
	ORDER BY site_option_group_parent_id";
	qGroup=db.execute("qGroup");
	groupStruct={};
	for(row in qGroup){
		if(not structkeyexists(groupStruct, row.site_id)){
			groupStruct[row.site_id]={};
		}
		groupStruct[row.site_id][row.site_option_group_id]={
			parentId:row.site_option_group_parent_id,
			name:row.site_option_group_name
		};
	}
	while(true){
		db.sql="select site_x_option_group_set_id, site_option_group.site_option_group_parent_id, site.site_id, site_option_group.site_option_group_name FROM
		#db.table("site", request.zos.zcoreDatasource)# site, 
		#db.table("site_x_option_group_set", request.zos.zcoreDatasource)# site_x_option_group_set,
		#db.table("site_option_group", request.zos.zcoreDatasource)# site_option_group
		where 
		site_deleted = #db.param(0)# and 
		site_x_option_group_set_deleted = #db.param(0)# and 
		site_option_group_deleted = #db.param(0)# and 
		site_option_group.site_option_group_id = site_x_option_group_set.site_option_group_id and 
		site_x_option_group_set.site_id = site.site_id and 
		site_option_group.site_id = site.site_id and 
		site_option_group.site_id = site_x_option_group_set.site_id and 
		site_option_group_enable_unique_url = #db.param(1)# and 
		site_x_option_group_set.site_x_option_group_set_active = #db.param(1)# and 
		site_x_option_group_set.site_x_option_group_set_approved = #db.param(1)# and 
		site_option_group_public_searchable = #db.param(1)# and 
		site.site_active=#db.param(1)# and 
		site.site_id <> #db.param(-1)# ";
		// site_option_group_parent_id = #db.param('0')# and 
		if(structkeyexists(form, 'sid') and form.sid NEQ ""){
			db.sql&=" and site.site_id = #db.param(form.sid)# ";
		}
		db.sql&=" LIMIT #db.param(offset)#, #db.param(limit)#";
		/*
		site_option_group_search_index_cfc_path <> #db.param('')# and 
		site_option_group_search_index_cfc_method <> #db.param('')# and 
		site_option_group_disable_site_map = #db.param(0)# and 
		*/
		qGroup=db.execute("qGroup"); 
		offset+=limit;
		if(qGroup.recordcount EQ 0){
			break;
		}else{
			for(row in qGroup){
				arrGroup=[];
				parentId=row.site_option_group_parent_id;
				while(true){
					if(parentId EQ 0){
						break;
					}
					tempStruct=groupStruct[row.site_id][parentId];
					parentId=tempStruct.parentId;
					arrayAppend(arrGroup, tempStruct.name);
				}
				arrayAppend(arrGroup, row.site_option_group_name);
				indexSiteOptionGroupRow(row.site_x_option_group_set_id, row.site_id, arrGroup); 
			}
		}
	}
	db.sql="delete from #db.table("search", request.zos.zcoreDatasource)# WHERE 
	site_id <> #db.param(-1)# and 
	app_id = #db.param(14)# and 
	search_deleted = #db.param(0)#";
	if(structkeyexists(form, 'sid') and form.sid NEQ ""){
		db.sql&=" and site_id = #db.param(form.sid)# ";
	}
	db.sql&="  and 
	search_updated_datetime < #db.param(startDatetime)# ";
	db.execute("qDelete");
	</cfscript>
</cffunction>

<cffunction name="searchReindexSet" localmode="modern" access="public">
	<cfargument name="setId" type="string" required="yes">
	<cfargument name="site_id" type="string" required="yes">
	<cfargument name="arrGroupName" type="array" required="yes">
	<cfscript>
	var db=request.zos.queryObject;
	var row=0;
	indexSiteOptionGroupRow(arguments.setId, arguments.site_id, arguments.arrGroupName);
	</cfscript>
</cffunction>

<cffunction name="deleteSiteOptionGroupSetIndex" localmode="modern" access="public">
	<cfargument name="setId" type="string" required="no" default="">
	<cfargument name="site_id" type="string" required="no" default="">
	<cfscript>
	var db=request.zos.queryObject;
	db.sql="DELETE FROM #db.table("search", request.zos.zcoredatasource)# 
	WHERE site_id =#db.param(arguments.site_id)# and 
	app_id = #db.param(14)# and 
	search_deleted = #db.param(0)# and 
	search_table_id = #db.param(arguments.setId)# ";
	db.execute("qDelete");
	</cfscript>
</cffunction>

<cffunction name="deactivateSiteOptionGroupSet" localmode="modern" access="public">
	<cfargument name="setId" type="string" required="yes">
	<cfargument name="site_id" type="string" required="yes">
	<cfargument name="isDisabledByUser" type="boolean" required="yes">
	<cfscript>
	var db=request.zos.queryObject;
	if(arguments.isDisabledByUser){
		approved=2;
	}else{
		approved=0;
	}
	db.sql="UPDATE #db.table("site_x_option_group_set", request.zos.zcoredatasource)# 
	SET 
	site_x_option_group_set_approved=#db.param(approved)#,
	site_x_option_group_set_updated_datetime=#db.param(request.zos.mysqlnow)# 
	WHERE site_id =#db.param(arguments.site_id)# and 
	site_x_option_group_set_deleted = #db.param(0)# and 
	site_x_option_group_set_id = #db.param(arguments.setId)# ";
	db.execute("qUpdate");
	db.sql="select site_option_group_id, site_x_option_group_set_image_library_id from #db.table("site_x_option_group_set", request.zos.zcoredatasource)# 
	WHERE site_id =#db.param(arguments.site_id)# and 
	site_x_option_group_set_deleted = #db.param(0)# and 
	site_x_option_group_set_id = #db.param(arguments.setId)# ";
	qSet=db.execute("qSet");
	if(qSet.recordcount){
		groupId=qSet.site_option_group_id;
		if(qSet.site_x_option_group_set_image_library_id NEQ 0){
			application.zcore.imageLibraryCom.unapproveLibraryId(qSet.site_x_option_group_set_image_library_id);
		}
		typeStruct=getTypeData(arguments.site_id);
		t9=getSiteData(arguments.site_id);
		var groupStruct=typeStruct.siteOptionGroupLookup[groupId]; 
		if(groupStruct.site_option_group_enable_cache EQ 1 and structkeyexists(t9.siteOptionGroupSet, arguments.setId)){
			groupStruct=t9.siteOptionGroupSet[arguments.setId];
			groupStruct.__approved=approved;
			application.zcore.functions.zCacheJsonSiteAndUserGroup(arguments.site_id, application.zcore.siteGlobals[arguments.site_id]); 
		}
	}
	
	</cfscript>
</cffunction>


<cffunction name="getStatusName" returntype="string" output="no" localmode="modern">
	<cfargument name="statusId" type="string" required="yes">
	<cfscript>
	if(arguments.statusId EQ 1){
		return 'Approved';
	}else if(arguments.statusId EQ 0){
		return 'Pending';
	}else if(arguments.statusId EQ 2){
		return 'Deactivated By User';
	}else if(arguments.statusId EQ 1){
		return 'Rejected';
	}else{
		throw("Invalid statusId, ""#arguments.statusId#""");
	}
	</cfscript>
</cffunction>


<cffunction name="prepareRecursiveData" localmode="modern" access="public">
	<cfargument name="site_option_id" type="string" required="yes">
	<cfargument name="site_option_group_id" type="string" required="yes">
	<cfargument name="setOptionStruct" type="struct" required="yes">
	<cfargument name="enableSearchView" type="boolean" required="yes">
	<cfscript>
	var db=request.zos.queryObject;
	var ts=arguments.setOptionStruct;
	local.arrLabel=[];
	local.arrValue=[];
	delimiter="|";
	if(arguments.setOptionStruct.selectmenu_delimiter EQ "|"){
		delimiter=",";
	}
	if(structkeyexists(ts,'selectmenu_groupid') and ts.selectmenu_groupid NEQ ""){
		db.sql="select s1.site_option_id labelFieldId, s2.site_option_id valueFieldId ";
		 if(structkeyexists(ts, 'selectmenu_parentfield') and ts.selectmenu_parentfield NEQ ""){
			db.sql&=",  s3.site_option_id parentFieldID ";
		 }
		 db.sql&="
		from 
		 #db.table("site_option", request.zos.zcoredatasource)# s1 , 
		 #db.table("site_option", request.zos.zcoredatasource)# s2";
		 if(structkeyexists(ts, 'selectmenu_parentfield') and ts.selectmenu_parentfield NEQ ""){
			db.sql&=",  #db.table("site_option", request.zos.zcoredatasource)# s3 ";
		 }
		 db.sql&=" WHERE 
		 s1.site_option_deleted = #db.param(0)# and 
		 s2.site_option_deleted = #db.param(0)# and
		s1.site_option_group_id = #db.param(ts.selectmenu_groupid)# and 
		s1.site_option_name = #db.param(ts.selectmenu_labelfield)# and 
		
		s2.site_id = s1.site_id and 
		s2.site_option_group_id = #db.param(ts.selectmenu_groupid)# and 
		s2.site_option_name = #db.param(ts.selectmenu_valuefield)# and 
		";
		 if(structkeyexists(ts, 'selectmenu_parentfield') and ts.selectmenu_parentfield NEQ ""){
			db.sql&=" s3.site_id = s1.site_id and 
			s3.site_option_group_id = #db.param(ts.selectmenu_groupid)# and 
			s3.site_option_name = #db.param(ts.selectmenu_parentfield)# and 
			s3.site_option_deleted = #db.param(0)# and ";
		 }
		 db.sql&="
		s2.site_id = #db.param(request.zos.globals.id)#
		GROUP BY s2.site_id ";
		local.qTemp=db.execute("qTemp");
		db.sql="select 
		s1.site_x_option_group_set_id id, 
		s1.site_x_option_group_value label,
		 s2.site_x_option_group_value value";
		 if(structkeyexists(ts, 'selectmenu_parentfield') and ts.selectmenu_parentfield NEQ ""){
			db.sql&=", s3.site_x_option_group_value parentId ";
		//	db.sql&=", s3.site_x_option_group_value parentId ";
		 }
		 db.sql&=" from 
		 #db.table("site_x_option_group", request.zos.zcoredatasource)# s1 , 
		 #db.table("site_x_option_group", request.zos.zcoredatasource)# s2 ";
		 if(structkeyexists(ts, 'selectmenu_parentfield') and ts.selectmenu_parentfield NEQ ""){
			db.sql&=" ,#db.table("site_x_option_group", request.zos.zcoredatasource)# s3";
		 }
		db.sql&=" WHERE 
		s1.site_x_option_group_deleted = #db.param(0)# and 
		s2.site_x_option_group_deleted = #db.param(0)# and 
		s1.site_option_id = #db.param(local.qTemp.labelFieldId)# and 
		s1.site_option_group_id = #db.param(ts.selectmenu_groupid)# and 
		s1.site_x_option_group_set_id = s2.site_x_option_group_set_id AND 
		s2.site_id = s1.site_id and 
		s2.site_option_id = #db.param(local.qTemp.valueFieldId)# and 
		s2.site_option_group_id = #db.param(ts.selectmenu_groupid)# and ";
		 if(structkeyexists(ts, 'selectmenu_parentfield') and ts.selectmenu_parentfield NEQ ""){
			db.sql&=" s3.site_id = s1.site_id and 
			s3.site_option_id = #db.param(local.qTemp.parentFieldID)# and 
			s3.site_option_group_id = #db.param(ts.selectmenu_groupid)# and 
			s1.site_x_option_group_set_id = s3.site_x_option_group_set_id and 
			s3.site_x_option_group_deleted = #db.param(0)# and ";
		 }
		if(not structkeyexists(ts, 'selectmenu_parentfield') or ts.selectmenu_parentfield EQ ""){
			if(arguments.site_option_group_id EQ ts.selectmenu_groupid){
				// exclude current site_x_option_group_set_id from query
				db.sql&="  s1.site_x_option_group_set_id <> #db.param(form.site_x_option_group_set_id)# and ";
			}
		}
		db.sql&=" s2.site_id = #db.param(request.zos.globals.id)#
		GROUP BY s1.site_x_option_group_set_id, s2.site_x_option_group_set_id
		ORDER BY label asc ";
		local.qTemp2=db.execute("qTemp2");
		//writedump(qtemp2);abort;
		if(structkeyexists(ts, 'selectmenu_parentfield') and ts.selectmenu_parentfield NEQ ""){
			local.ds=structnew();
			local.ds2=structnew();
			for(local.row2 in local.qTemp2){
				if(local.row2.parentId EQ ""){
					local.row2.parentId=0;
				}
				if(not structkeyexists(local.ds, local.row2.parentId)){
					local.ds[local.row2.parentId]={};
					local.ds2[local.row2.parentId]=[];
				}
				local.ds[local.row2.parentId][local.row2.id]={ value: local.row2.value, label:local.row2.label, id:local.row2.id, parentId:local.row2.parentId };
			}
			for(local.n in local.ds){
				local.arrKey=structsort(local.ds[local.n], "text", "asc", "label");
				for(local.f=1;local.f LTE arraylen(local.arrKey);local.f++){
					arrayAppend(local.ds2[local.n], local.ds[local.n][local.arrKey[local.f]]);
				}
			}
			// all subcategories sorted, now do the combine + indent
			if(structkeyexists(local.ds2, "0")){
				local.arrCurrent=local.ds2["0"];
			}
			if(arguments.enableSearchView){
				for(n in local.ds){
					for(g in local.ds[n]){
						arrChildValues=[];
						arrChildValues=variables.getChildValues(local.ds, local.ds[n][g], arrChildValues, 1);
						arraySort(arrChildValues, "text");
						//local.ds[n][g].value=arrayToList(arrChildValues, delimiter);
						local.ds[n][g].idChild=arrayToList(arrChildValues, delimiter);
					}
				}
			}
			if(structkeyexists(local.ds2, "0")){
//				writedump(arguments.setoptionstruct);				writedump(local.ds2);				writedump(local.ds);				writedump(local.arrValue);				abort;/**/
				variables.rebuildParentStructData(local.ds2, local.arrLabel, local.arrValue, local.arrCurrent, 0);
			}
		}
	}
	local.rs= { 
		ts: ts, 
		arrLabel: local.arrLabel, 
		arrValue: local.arrValue
	};
	if(structkeyexists(local, 'qTemp2')){
		local.rs.qTemp2=local.qTemp2;
	}
	return local.rs;
	</cfscript>
</cffunction>

<cffunction name="getChildValues" localmode="modern" returntype="array" access="private">
	<cfargument name="struct" type="struct" required="yes">
	<cfargument name="currentStruct" type="struct" required="yes">
	<cfargument name="arrChild" type="array" required="yes">
	<cfargument name="level" type="numeric" required="yes">
	<cfscript>
	if(arguments.level GT 50){
		throw("Possible infinite recursion detected in siteOptionCom.getChildValues().");
	}
	arrayAppend(arguments.arrChild, arguments.currentStruct.id);
	if(structkeyexists(arguments.struct, arguments.currentStruct.id)){
		for(i in arguments.struct[arguments.currentStruct.id]){
			arguments.arrChild=this.getChildValues(arguments.struct, arguments.struct[arguments.currentStruct.id][i], arguments.arrChild, arguments.level+1);
		}
	}
	return arguments.arrChild;
	</cfscript>
</cffunction>


<cffunction name="indexSiteOptionGroupRow" localmode="modern" access="public">
	<cfargument name="setId" type="string" required="yes">
	<cfargument name="site_id" type="string" required="yes">
	<cfargument name="arrGroupName" type="array" required="yes">
	<cfscript>
	var db=request.zos.queryObject;
	var ts=0;
	var i=0;
	dataStruct=application.zcore.functions.zGetSiteOptionGroupSetById(arguments.setId, arguments.site_id, arguments.arrGroupName);
	var t9=getTypeData(arguments.site_id);
	if(not structkeyexists(dataStruct, '__approved') or dataStruct.__approved NEQ 1){
		deleteSiteOptionGroupSetIndex(arguments.setId, arguments.site_id);
		return;
	}
	groupStruct=t9.siteOptionGroupLookup[dataStruct.__groupId]; 
	if(groupStruct.site_option_group_search_index_cfc_path EQ ""){
		customSearchIndexEnabled=false;
	}else{ 
		customSearchIndexEnabled=true;
		if(left(groupStruct.site_option_group_search_index_cfc_path, 5) EQ "root."){  
			local.cfcpath=replace(groupStruct.site_option_group_search_index_cfc_path, 'root.',  application.zcore.functions.zGetRootCFCPath(application.zcore.functions.zvar('shortDomain', arguments.site_id)));
		}else{
			local.cfcpath=groupStruct.site_option_group_search_index_cfc_path;
		}
	}
	searchCom=application.zcore.functions.zcreateobject("component", "zcorerootmapping.com.app.searchFunctions");
	ds=searchCom.getSearchIndexStruct();
	ds.app_id=14; 
	ds.search_table_id=local.dataStruct.__setId;
	ds.site_id=arguments.site_id;
	ds.search_content_datetime=local.dataStruct.__dateModified;
	ds.search_url=dataStruct.__url;
	ds.search_title=dataStruct.__title;
	ds.search_summary=dataStruct.__summary;


	if(structkeyexists(dataStruct, '__image_library_id') and dataStruct.__image_library_id NEQ 0){
		ts={};
		ts.output=false;
		ts.size="150x120";
		ts.layoutType="";
		ts.image_library_id=dataStruct.__image_library_id;
		ts.forceSize=true;
		ts.crop=0;
		ts.offset=0;
		ts.limit=1; // zero will return all images
		var arrImage=request.zos.imageLibraryCom.displayImages(ts);
		if(arraylen(arrImage)){
			ds.search_image=arrImage[1].link;
		}
	}
	if(customSearchIndexEnabled){
		local.tempCom=application.zcore.functions.zcreateobject("component", local.cfcpath); 
		local.tempCom[groupStruct.site_option_group_search_index_cfc_method](dataStruct, ds);
	}else{
		arrFullText=[]; 
		if(structkeyexists(t9.siteOptionGroupFieldLookup, dataStruct.__groupId)){
			for(i in t9.siteOptionGroupFieldLookup[dataStruct.__groupId]){
				c=t9.siteOptionLookup[i];
				if(c.site_option_enable_search_index EQ 1){
					arrayAppend(arrFullText, dataStruct[c.name]);
				}
			}
		}
		ds.search_fulltext=arrayToList(arrFullText, " ");
	}
	//writedump(ds);abort;
	searchCom.saveSearchIndex(ds);
	</cfscript>
</cffunction>
 
<!--- application.zcore.siteOptionCom.activateSiteOptionAppId(site_option_app_id); --->
<cffunction name="ActivateSiteOptionAppId" localmode="modern" returntype="any" output="no">
	<cfargument name="site_option_app_id" type="string" required="yes">
	<cfscript>
	var db=request.zos.queryObject;
	 db.sql="UPDATE #db.table("site_option_app", request.zos.zcoreDatasource)# site_option_app 
	 SET site_option_app_active = #db.param('1')#, 
	 site_option_app_updated_datetime=#db.param(request.zos.mysqlnow)# 
	 WHERE site_option_app_id=#db.param(arguments.site_option_app_id)# and 
	 site_option_app_deleted = #db.param(0)# and 
	 site_id = #db.param(request.zos.globals.id)#";
	 db.execute("q");
	</cfscript>
</cffunction>

<!--- application.zcore.siteOptionCom.getCurrentSiteOptionAppId(); --->
<cffunction name="getCurrentSiteOptionAppId" localmode="modern" output="no" returntype="any">
	<cfscript>
	if(structkeyexists(request.zos, "currentSiteOptionAppId")){
		return request.zos.currentSiteOptionAppId;
	}else{
		return 0;
	}
	</cfscript>
</cffunction>

<cffunction name="setCurrentSiteOptionAppId" localmode="modern" output="no" returntype="any">
	<cfargument name="id" type="string" required="yes">
	<cfscript>
	request.zos.currentSiteOptionAppId=arguments.id;
	</cfscript>
</cffunction>

<!--- /z/_com/app/site-option?method=getNewSiteOptionAppId --->
<cffunction name="getNewSiteOptionAppId" localmode="modern" access="remote" roles="member" returntype="any" output="no">
	<cfargument name="app_id" type="string" required="yes">
	<cfscript>
	var site_option_app_id=0;
	var ts=structnew();
	ts.datasource=request.zos.zcoreDatasource;
	ts.table="site_option_app";
	ts.struct=structnew();
	ts.struct.site_id=request.zos.globals.id;
	ts.struct.app_id=arguments.app_id;
	ts.struct.site_option_app_active=0;
	//ts.debug=true;
	//ts.struct.site_option_app_datetime=request.zos.mysqlnow;
	site_option_app_id=application.zcore.functions.zInsert(ts);
	if(site_option_app_id EQ false){
		application.zcore.template.fail("Error: zcorerootmapping.com.app.site-option.cfc - getNewSiteOptionAppId() failed to insert into site_option_app.");
	}
	if(application.zcore.functions.zso(form, 'method') EQ 'getNewSiteOptionAppId'){
		writeoutput('new id:'&site_option_app_id);
		application.zcore.functions.zabort();
	}else{
		return site_option_app_id;
	}
	</cfscript>
</cffunction>

<!--- this.getSiteOptionAppById(site_option_app_id, app_id, newOnMissing); --->
<cffunction name="getSiteOptionAppById" localmode="modern" returntype="any" output="yes">
	<cfargument name="site_option_app_id" type="string" required="yes">
	<cfargument name="app_id" type="string" required="yes">
	<cfargument name="newOnMissing" type="boolean" required="no" default="#true#">
	<cfscript>
	var qG=0;
	var db=request.zos.queryObject;
	db.sql="SELECT * FROM #request.zos.queryObject.table("site_option_app", request.zos.zcoreDatasource)# site_option_app 
	WHERE site_option_app_id = #db.param(arguments.site_option_app_id)# and 
	site_option_app_deleted = #db.param(0)# and 
	site_id =#db.param(request.zos.globals.id)#";
	qG=db.execute("qG");
	if(qG.recordcount EQ 0){
		if(arguments.newOnMissing){
			arguments.site_option_app_id=this.getNewSiteOptionAppId(arguments.app_id);
			db.sql="SELECT * FROM #request.zos.queryObject.table("site_option_app", request.zos.zcoreDatasource)# site_option_app 
			WHERE site_option_app_id = #db.param(arguments.site_option_app_id)# and 
			site_option_app_deleted = #db.param(0)# and
			site_id =#db.param(request.zos.globals.id)#";
			qG=db.execute("qG");
		}else{
			return false;
		}
	}
	return qG;
	</cfscript>
</cffunction> 

<!--- application.zcore.siteOptionCom.deleteSiteOptionAppId(site_option_app_id); --->
<cffunction name="deleteSiteOptionAppId" localmode="modern" returntype="any" output="no">
	<cfargument name="site_option_app_id" type="string" required="yes">
	<cfargument name="site_id" type="string" required="no" default="#request.zos.globals.id#">
	<cfscript>
	var q=0;
	var db=request.zos.queryObject;
	typeStruct=getTypeData(arguments.site_id);
	if(arguments.site_option_app_id NEQ 0 and arguments.site_option_app_id NEQ ""){
		db.sql="SELECT * FROM #request.zos.queryObject.table("site_x_option", request.zos.zcoreDatasource)# site_x_option, 
		#request.zos.queryObject.table("site_option", request.zos.zcoreDatasource)# site_option 
		WHERE site_x_option.site_id = #db.param(request.zos.globals.id)# and 
		site_x_option_deleted = #db.param(0)# and 
		site_option_deleted = #db.param(0)# and 
		site_option.site_id=#db.param(arguments.site_id)# and  
		site_x_option.site_option_id = site_option.site_option_id and 
		site_x_option.site_option_app_id=#db.param(arguments.site_option_app_id)# and 
		site_option_type_id IN (#db.param(3)#, #db.param(9)#) and 
		site_x_option_value <> #db.param('')# and 
		site_option_type_id=#db.param('3')#";
		path=application.zcore.functions.zvar('privatehomedir',arguments.site_id)&'zupload/site-options/';
		securepath=application.zcore.functions.zvar('privatehomedir',arguments.site_id)&'zuploadsecure/site-options/';
		qS=db.execute("qS");
		for(i=1;i LTE qS.recordcount;i++){
			optionStruct=typeStruct.siteOptionLookup[row.site_option_id].optionStruct;
			if(application.zcore.functions.zso(optionStruct, 'file_securepath') EQ 'Yes'){
				if(fileexists(securepath&qS.site_x_option_value[i])){
					application.zcore.functions.zdeletefile(securepath&qS.site_x_option_value[i]);
				}
			}else{
				if(fileexists(path&qS.site_x_option_value[i])){
					application.zcore.functions.zdeletefile(path&qS.site_x_option_value[i]);
				}
				if(qS.site_x_option_original[i] NEQ "" and fileexists(path&qS.site_x_option_value[i])){
					application.zcore.functions.zdeletefile(path&qS.site_x_option_original[i]);
				}
			}
		}
		db.sql="SELECT * FROM #request.zos.queryObject.table("site_x_option_group", request.zos.zcoreDatasource)# site_x_option_group, 
		#request.zos.queryObject.table("site_option", request.zos.zcoreDatasource)# site_option 
		WHERE site_x_option_group.site_id = #db.param(request.zos.globals.id)# and 
		site_option.site_id=#db.param(arguments.site_id)# and  
		site_x_option_group.site_option_id = site_option.site_option_id and 
		site_x_option_group.site_option_app_id=#db.param(arguments.site_option_app_id)# and 
		site_option_type_id IN (#db.param(3)#, #db.param(9)#) and 
		site_x_option_group_value <> #db.param('')# and 
		site_option_deleted = #db.param(0)# and 
		site_x_option_group_deleted = #db.param(0)# and 
		site_option_type_id=#db.param('3')#";
		qS=db.execute("qS");
		for(i=1;i LTE qS.recordcount;i++){
			optionStruct=typeStruct.siteOptionLookup[row.site_option_id].optionStruct;
			if(application.zcore.functions.zso(optionStruct, 'file_securepath') EQ 'Yes'){
				if(fileexists(securepath&qS.site_x_option_group_value[i])){
					application.zcore.functions.zdeletefile(securepath&qS.site_x_option_group_value[i]);
				}
			}else{
				if(fileexists(path&qS.site_x_option_group_value[i])){
					application.zcore.functions.zdeletefile(path&qS.site_x_option_group_value[i]);
				}
				if(qS.site_x_option_group_original[i] NEQ "" and fileexists(path&qS.site_x_option_group_original[i])){
					application.zcore.functions.zdeletefile(path&qS.site_x_option_group_original[i]);
				}
			}
		}
		
		db.sql="DELETE FROM #request.zos.queryObject.table("site_x_option", request.zos.zcoreDatasource)#  
		WHERE site_option_app_id = #db.param(arguments.site_option_app_id)# and 
		site_x_option_deleted = #db.param(0)# and 
		site_id = #db.param(arguments.site_id)#";
		q=db.execute("q");
		db.sql="DELETE FROM #request.zos.queryObject.table("site_x_option_group", request.zos.zcoreDatasource)#  
		WHERE site_option_app_id = #db.param(arguments.site_option_app_id)# and 
		site_x_option_group_deleted = #db.param(0)# and 
		site_id = #db.param(arguments.site_id)#";
		q=db.execute("q");
		db.sql="DELETE FROM #request.zos.queryObject.table("site_x_option_group_set", request.zos.zcoreDatasource)#  
		WHERE site_option_app_id = #db.param(arguments.site_option_app_id)# and 
		site_x_option_group_set_deleted = #db.param(0)# and 
		site_id = #db.param(arguments.site_id)#";
		q=db.execute("q");
		db.sql="DELETE FROM #request.zos.queryObject.table("site_option_app", request.zos.zcoreDatasource)#  
		WHERE site_option_app_id = #db.param(arguments.site_option_app_id)# and 
		site_option_app_deleted = #db.param(0)# and 
		 site_id = #db.param(arguments.site_id)#";
		q=db.execute("q");
		application.zcore.functions.zOS_cacheSiteAndUserGroups(arguments.site_id);
	}
	</cfscript>
</cffunction>

<cffunction name="siteoptionappform" localmode="modern" access="remote" roles="member" returntype="any" output="yes">
	<cfscript>
	var local=structnew();
	var c=0;
	application.zcore.template.setTemplate("zcorerootmapping.templates.blank",true,true);
	c=application.zcore.functions.zcreateobject("component", "zcorerootmapping.mvc.z.admin.controller.site-options");
	c.index();
	</cfscript>
</cffunction>

<!---  
ts=structnew();
ts.name="site_option_app_id";
ts.app_id=0;
ts.value=site_option_app_id;
application.zcore.siteOptionCom.getSiteOptionForm(ts); --->
<cffunction name="getSiteOptionForm" localmode="modern" returntype="any" output="yes">
	<cfargument name="ss" type="struct" required="yes">
	<cfscript>
	var qLibrary=this.getSiteOptionAppById(arguments.ss.value, arguments.ss.app_id);
	var site_option_app_id=qLibrary.site_option_app_id;
	</cfscript>
<script type="text/javascript">
	/* <![CDATA[ */
	function showSiteOptionWindow(){
		var windowSize=zGetClientWindowSize();
		var modalContent1='<iframe src="/z/admin/site-options/index?site_option_app_id=#site_option_app_id#&amp;ztv='+Math.random()+'"  style="margin:0px;border:none; overflow:auto;" seamless="seamless" width="100%" height="95%"><\/iframe>';		
		zShowModal(modalContent1,{'width':windowSize.width-100,'height':windowSize.height-100});
	}
	/* ]]> */
	</script>
<input type="hidden" name="#arguments.ss.name#" value="#site_option_app_id#" />
<h2><a href="##" onclick="showSiteOptionWindow(); return false;">Edit Custom Fields</a></h2>

  
</cffunction>



<!--- 
// you must have a group by in your query or it may miss rows
ts=structnew();
ts.site_option_app_id_field="rental.rental_site_option_app_id";
ts.count = 1; // how many images to get
application.zcore.siteOptionCom.getImageSQL(ts);
 --->
<cffunction name="getImageSQL" localmode="modern" returntype="any" output="yes">
	<cfargument name="ss" type="struct" required="yes">
	<cfscript>
	var qImages=0;
	var arrOutput=arraynew(1);
	var ts=structnew();
	var rs=structnew();
	ts.site_option_app_id_field="";
	ts.count=1;
	structappend(arguments.ss,ts,false);
	if(arguments.ss.site_option_app_id_field EQ ""){
		application.zcore.template.fail("Error: zcorerootmapping.com.app.site-option.cfc - displayImages() failed because arguments.ss.site_option_app_id_field is required.");	
	}
	rs.leftJoin="LEFT JOIN `"&request.zos.zcoreDatasource&"`.image ON "&arguments.ss.site_option_app_id_field&" = image.site_option_app_id and image_sort <= #db.param(arguments.ss.count)# and image.site_id = #db.param(request.zos.globals.id)#";
	rs.select=", cast(GROUP_CONCAT(image_id ORDER BY image_sort SEPARATOR '\t') as char) imageIdList, 
	cast(GROUP_CONCAT(image_caption ORDER BY image_sort SEPARATOR '\t') as char) imageCaptionList, 
	cast(GROUP_CONCAT(image_file ORDER BY image_sort SEPARATOR '\t') as char) imageFileList, 
	cast(GROUP_CONCAT(image_updated_datetime ORDER BY image_sort SEPARATOR '\t') as char) imageUpdatedDateList";
	return rs;
	</cfscript>
</cffunction>




<!--- 
ts=structnew();
ts.site_option_app_id;
ts.output=true;
ts.query=qImages;
ts.row=currentrow;
ts.size="250x160";
ts.crop=0;
ts.count = 1; // how many images to get
application.zcore.siteOptionCom.displayImageFromSQL(ts);
 --->
<cffunction name="displayImageFromSQL" localmode="modern" returntype="any" output="yes">
	<cfargument name="ss" type="struct" required="yes">
	<cfscript>
	var qImages=0;
	var arrImageFile=0;
	var g2=0;
	var arrOutput=arraynew(1);
	var ts=structnew();
	var rs=structnew();
	var count=0;
	var arrId=arraynew(1);
	var arrCaption=arraynew(1);
	ts.output=true;
	ts.row=1;
	ts.crop=0;
	ts.size="#request.zos.globals.maximagewidth#x2000";
	structappend(arguments.ss,ts,false);
	if(arguments.ss.query.imageIdList[arguments.ss.row] EQ ""){
		arguments.ss.count=0;
	}else{
		arguments.ss.count=min(arguments.ss.count,arraylen(listtoarray(arguments.ss.query.imageIdList[arguments.ss.row],chr(9),true)));
	}
	if(arguments.ss.count EQ 0){
		return arrOutput;
	}
	if(arguments.ss.site_option_app_id EQ 0){
		if(arguments.ss.output){
			return;
		}else{
			return arrOutput;
		}
	}
	application.zcore.siteOptionCom.registerSize(arguments.ss.site_option_app_id, arguments.ss.size, arguments.ss.crop);
	</cfscript>
	<cfif arguments.ss.output>
		<cfloop query="arguments.ss.query" startrow="#arguments.ss.row#" endrow="#arguments.ss.row#">
			<cfscript>arrCaption=listtoarray(arguments.ss.query.imageCaptionList,chr(9),true);
			arrId=listtoarray(arguments.ss.query.imageIdList,chr(9),true);
			arrImageFile=listtoarray(arguments.ss.query.imageFileList,chr(9),true);
			arrImageUpdatedDate=listtoarray(arguments.ss.query.imageUpdatedDateList, chr(9), true);
			</cfscript>
			<cfloop from="1" to="#arguments.ss.count#" index="g2">
				<img src="#application.zcore.siteOptionCom.getImageLink(arguments.ss.site_option_app_id, arrId[g2], arguments.ss.size, arguments.ss.crop, true, arrCaption[g2], arrImageFile[g2], arrImageUpdatedDate[g2])#" <cfif arrCaption[g2] NEQ "">alt="#htmleditformat(arrCaption[g2])#"</cfif> style="border:none;" />
				<cfif arrCaption[g2] NEQ ""><br /><div style="padding-top:5px;">#arrCaption[g2]#</div></cfif><br /><br />
			</cfloop>
		</cfloop>
	<cfelse>
		<cfloop query="arguments.ss.query" startrow="#arguments.ss.row#" endrow="#arguments.ss.row#">
			<cfscript>
			arrCaption=listtoarray(arguments.ss.query.imageCaptionList,chr(9),true);
			arrId=listtoarray(arguments.ss.query.imageIdList,chr(9),true);
			arrImageFile=listtoarray(arguments.ss.query.imageFileList,chr(9),true);
			arrImageUpdatedDate=listtoarray(arguments.ss.query.imageUpdatedDateList, chr(9), true);
			if(arraylen(arrCaption) EQ 0){ arrayappend(arrCaption,""); }
			if(arraylen(arrId) EQ 0){ arrayappend(arrId,""); }
			if(arraylen(arrImageFile) EQ 0){ arrayappend(arrImageFile,""); }
			if(arraylen(arrImageUpdatedDate) EQ 0){ arrayappend(arrImageUpdatedDate,""); }
			</cfscript>
			<cfloop from="1" to="#arguments.ss.count#" index="g2">
				<cfscript>
				ts=structnew();
				ts.link=application.zcore.siteOptionCom.getImageLink(arguments.ss.site_option_app_id, arrId[g2], arguments.ss.size, arguments.ss.crop, true, arrCaption[g2], arrImageFile[g2], arrImageUpdatedDate[g2]);
				ts.caption=arrCaption[g2];
				ts.id=arrId[g2];
				arrayappend(arrOutput,ts);
				</cfscript>
			</cfloop>
		</cfloop>
		<cfscript>return arrOutput;</cfscript>
	</cfif>
</cffunction>


</cfoutput>
</cfcomponent>