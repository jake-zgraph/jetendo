<cfcomponent>
<cfoutput>

<cffunction name="init" localmode="modern" access="private">
	<cfargument name="ss" type="struct" required="yes">
	<cfscript>
	if(variables.initCalled?:false){
		return;
	}
	variables.initCalled=true;
	ss=arguments.ss;

	ts={
		// required
		// optional

		customInsertUpdate:false, // true disables the normal zInsert/zUpdate calls, so you can implement them in afterInsert and afterUpdate instead
		methods:{}, // function receives struct named row
		fileFields:[],
		imageLibraryFields:[],
		validateFields:[],
		primaryKeyField:"",
		requiredParams:[],
		requireFeatureAccess:"",
		disableAddEdit:false, // true disables add/edit/insert/update of leads
		columnSortingEnabled:false,
		pagination:true,
		paginationIndex:"zIndex",
		perpage:10,
		title:"",
		metaField:"",
		listURL:"",
		quickLinks:[], 
		navLinks:[],
		titleLinks:[
		/*{
			link:"/z/admin/new-interface/add",
			text:"Add"
		}*/],
		searchFields:[/*{
			fields:[{
				formField:'Search By Name: <input type="search" name="search_name" id="search_name" value="#htmleditformat(form.search_name)#"> ',
				field:"search_name"
			}]
		}*/],
		columns:[/*{
			label:'Name',
			field:'office_name',
			sortable:true,

		}*/],
		rowSortingEnabled:false
	}; 
	structappend(ss, ts, false);
	structappend(variables, ss, true);

	if(variables.metaField NEQ ""){
		variables.metaCom=createObject("component", "zcorerootmapping.com.zos.meta");
	}

	if(variables.requireFeatureAccess NEQ ""){ 
		if(form.method EQ "index" or form.method EQ "edit" or form.method EQ "add"){
			application.zcore.adminSecurityFilter.requireFeatureAccess(variables.requireFeatureAccess);	
		}else{
			// all other methods might be writing
			application.zcore.adminSecurityFilter.requireFeatureAccess(variables.requireFeatureAccess, true);	
		}
	}
	form[variables.primaryKeyField]=application.zcore.functions.zso(form, variables.primaryKeyField, true, 0);
	requiredParams=[];
	for(param in variables.requiredParams){
		form[param]=application.zcore.functions.zso(form, param);
		arrayAppend(requiredParams, "#param#=#urlencodedformat(form[param])#");
	}
	variables.requiredParamsQS=arrayToList(requiredParams, "&");

	form[variables.paginationIndex]=application.zcore.functions.zso(form, variables.paginationIndex, true, 1);
	if(variables.columnSortingEnabled){
		variables.qSortCom = application.zcore.functions.zcreateobject("component","zcorerootmapping.com.display.querySort");
		form[variables.pageZSID] = variables.qSortCom.init(variables.pageZSID);
	}
	if(variables.rowSortingEnabled){
		var queueSortStruct = StructNew();
		variables.queueSortCom = application.zcore.functions.zcreateobject("component", "zcorerootmapping.com.display.queueSort");
		queueSortStruct.tableName = variables.tableName;
		queueSortStruct.datasource=variables.datasource;
		queueSortStruct.sortFieldName = variables.sortField;
		queueSortStruct.primaryKeyName = variables.primaryKeyField;
		queueSortStruct.where=" 1 = 1 ";
		if(variables.hasSiteId){
			queueSortStruct.where&=" and site_id=#request.zos.globals.id# ";
		}
		if(variables.deletedField NEQ ""){
			queueSortStruct.where&=" and #variables.deletedField#=0 ";
		}
		queueSortStruct.ajaxURL=variables.prefixURL&"index";
		queueSortStruct.ajaxTableId="sortRowTable";
		variables.queueSortCom.init(queueSortStruct);
		variables.queueSortCom.returnJson();
 	}
	</cfscript>
</cffunction>	

<cffunction name="getSortColumnSQL" localmode="modern" access="private"> 
	<cfscript> 
	if(variables.columnSortingEnabled){
		return variables.sortColumnSQL;
	}
	return '';
	</cfscript>
</cffunction>	

<!---
a version of index list with divs for the table instead of <table>
		<cfif rs.qData.recordcount EQ 0>
			<p>No records have been added.</p>
		<cfelse>
			<div class="z-manager-pagination">
				#searchNav#
			</div>
			<div id="sortRowTable" class="z-manager-table">
				<div class="z-manager-table-head">
					<div class="z-manager-table-row">
						<cfscript>
						for(column in variables.columns){
							echo('<div class="z-manager-table-column">');
							if(structkeyexists(column, 'fields')){
								for(field in column.fields){
									if(structkeyexists(field, 'sortable') and field.sortable){
										echo('<a href="#variables.qSortCom.getColumnURL(field.field, currentLink)#">#field.label#</a> 
										#variables.qSortCom.getColumnIcon(field.field)#');
									}else{
										echo(field.label);
									} 
								}
							}else{
								if(structkeyexists(column, 'sortable') and column.sortable){
									echo('<a href="#variables.qSortCom.getColumnURL(column.field, currentLink)#">#column.label#</a> 
									#variables.qSortCom.getColumnIcon(column.field)#');
								}else{
									echo(column.label);
								} 
							}
							echo('</div>');
						} 
						</cfscript> 
					</div>
				</div>
				<div class="z-manager-table-body">
					<cfscript>
					rowCount=0;
					for(row in rs.qData){
						rowCount++;
						echo('<div class="z-manager-table-row" ');
						if(variables.rowSortingEnabled){
							echo(variables.queueSortCom.getRowHTML(row[variables.primaryKeyField]));
						}  
						echo('>');
						row.currentRow=rowCount;
						columns=[];
						request.zArrErrorMessages=["#variables.methods.getListRow# was called.  The error may be in this function."];
						variables[variables.methods.getListRow](row, columns);
						request.zArrErrorMessages=[];
						for(column in columns){
							echo('<div class="z-manager-table-column ');
							if(structkeyexists(column, 'class')){
								echo('#column.class#');
							}
							echo('"');
							if(structkeyexists(column, 'style')){
								echo(' style="#column.style#"');
							}
							echo('>#column.field#</div>');
						}
						echo('</div>');
					}
					</cfscript> 
				</div>
			</div>
			<div class="z-manager-pagination">
				#searchNav#
			</div>
		</cfif>
	</div>
 ---> 

<cffunction name="index" localmode="modern" access="private"> 
	<cfscript> 
	var db=request.zos.queryObject; 
	init();
	form.searchOn=application.zcore.functions.zso(form, 'searchOn', true, 0);
	if(variables.columnSortingEnabled){
		variables.sortColumnSQL=variables.qSortCom.getorderby(false);  
		if(variables.sortColumnSQL NEQ ""){
			arrayAppend(variables.titleLinks, {
				link:variables.prefixURL&"index",
				text:"Clear Sorting"
			});
		}
	}
	//application.zcore.functions.zRequireDataTables();
	params=[];//&#variables.pageZSID#=#form[variables.pageZSID]#");
	if(variables.requiredParamsQS NEQ ""){
		arrayAppend(params, variables.requiredParamsQS);
	}
	if(form.searchOn EQ 1){
		arrayAppend(params, "searchOn=#form.searchOn#");
	} 
	
	request.zArrErrorMessages=["#variables.methods.getListData# was called.  The error may be in this function."];
	rs=variables[variables.methods.getListData]();
	request.zArrErrorMessages=[];
	if(not structkeyexists(rs, 'qData') or not structkeyexists(rs, 'qCount') or not structkeyexists(rs, 'searchFields')){
		throw("variables.methods.getListData function must return a struct like: {qData:qData, qCount:qCount, searchFields:[]}");
	}
	variables.searchFields=[]; 
	if(structkeyexists(rs, 'searchFields')){
		variables.searchFields=rs.searchFields;
	}
 	for(group in variables.searchFields){
 		if(structkeyexists(group, 'fields')){
		 	for(field in group.fields){
		 		form[field.field]=application.zcore.functions.zso(form, field.field); 

				if(form.searchOn EQ 1){
 					arrayAppend(params, "#field.field#=#urlencodedformat(form[field.field])#");
 				}
		 	}
		}
	}
 	currentLink=application.zcore.functions.zURLAppend(request.zos.originalURL, arrayToList(params, "&"));


	application.zcore.functions.zStatusHandler(request.zsid);

	
	if(variables.pagination){
		searchStruct = StructNew();
		searchStruct.showString = "";
		searchStruct.indexName = variables.paginationIndex;
		searchStruct.url = currentLink;
		searchStruct.index=form[variables.paginationIndex];
		searchStruct.buttons = 5;
		searchStruct.count = rs.qCount.count;
		searchStruct.perpage = variables.perpage;
		searchNav=application.zcore.functions.zSearchResultsNav(searchStruct);
		if(rs.qCount.count <= searchStruct.perpage){
			searchNav="";
		}
	}else{
		searchNav="";
	}
	</cfscript>

	<div class="z-manager-list-view">
		<cfscript>
		if(arrayLen(variables.navLinks)){
			echo('<div class="z-manager-nav-links z-float z-mb-10">');
			for(link in variables.navLinks){
				echo('<a href="#link.link#"');
				if(structkeyexists(link, 'target')){
					echo(' target="#link.target#"');
				}
				echo('>#link.label#</a> / ');
			}
			echo('</div>');
		}
		</cfscript>
		<div class="z-float">
			<div class="z-manager-quick-menu">
				<h2>#variables.title#</h2>
				<cfscript>
				if(arrayLen(variables.quickLinks)){
					echo('<div class="z-manager-quick-menu-links">');
					for(link in variables.quickLinks){
						echo('<a href="#link.link#"');
						if(structkeyexists(link, 'target')){
							echo(' target="#link.target#"');
						}
						if(structkeyexists(link, 'onclick')){
							echo(' onclick="#link.onclick#"');
						}
						echo('>#link.label#</a>');
					}
					echo('</div>');
				}
				</cfscript>
			</div>
			<div class="z-manager-quick-menu-side-links"> 
				<cfif not variables.disableAddEdit>
					<a href="#variables.prefixURL#add?modalpopforced=1&#variables.requiredParamsQS#" onclick="zTableRecordAdd(this, 'sortRowTable'); return false;" class="z-manager-search-button z-manager-quick-add-link">Add</a>
				</cfif>
				<cfscript>
				for(link in variables.titleLinks){
					echo('<a href="#link.link#" class="z-manager-search-button">#link.label#</a>');
				}
				</cfscript>
			</div>
		</div>

		<cfif arraylen(variables.searchFields)>
			<div class="z-float">
				<a href="##" class="z-manager-list-tab-button <cfif form.searchOn EQ 0>active</cfif>" data-tab="" data-click-location="#request.zos.originalURL#">All Data</a>
				<a href="##" class="z-manager-list-tab-button <cfif form.searchOn EQ 1>active</cfif>" data-tab="z-manager-search-fields"><div class="z-float-left">Search</div><div class="z-show-at-992 z-float-left">&nbsp;</div><div class="z-manager-list-tab-refine">Refine</div></a> 
			</div>
			<div class="z-manager-tab-container z-float" <cfif form.searchOn EQ 0>style="display:none;"</cfif>>
				<div class="z-manager-list-tab z-manager-search-fields <cfif form.searchOn EQ 1>active</cfif>">
					<form action="#currentLink#" method="get">
						<input type="hidden" name="searchOn" value="1">
						<cfscript>
						for(group in variables.searchFields){
							echo('<div class="z-manager-search-group"');
							if(structkeyexists(group, 'groupStyle')){
								echo(' style="#group.groupStyle#"');
							}
							echo('>');
							for(field in group.fields){

								echo('<div class="z-manager-search-field">');
								if(structkeyexists(field, 'label')){
									echo('<div class="z-manager-search-field-label"');
									if(structkeyexists(field, 'labelStyle')){
										echo(' style="#field.labelStyle#"');
									}
									echo('>#field.label#</div>');
								}
								echo('<div class="z-manager-search-field-form"');
								if(structkeyexists(field, 'fieldStyle')){
									echo(' style="#field.fieldStyle#"');
								}
								echo('>#field.formField#</div></div>');
							}
							echo('</div>');
						}
						</cfscript> 
						<div class="z-manager-search-submit">
							<input type="submit" name="submit1" class="z-manager-search-button" value="Submit">
						</div>
					</form>
				</div>
			</div>
		</cfif>
		<cfif not variables.disableAddEdit and application.zcore.functions.zso(form, 'zManagerAddOnLoad', true, 0) EQ 1>
			<script type="text/javascript">
			zArrDeferredFunctions.push(function(){
				$(".z-manager-quick-add-link").trigger("click");
			});
			</script>
		</cfif>

		<cfif rs.qData.recordcount EQ 0>
			<div class="z-float" style="border:1px solid ##CCC; background-color:##FFF; padding:5px;">No data found.</div>
		<cfelse>
			<div class="z-manager-pagination" style=" border-bottom:none;">
				#searchNav#
			</div>
			<table id="sortRowTable" class="table-list" style="width:100%;">
				<thead>
				<tr>
					<cfscript>
					for(column in variables.columns){
						echo('<th>');
						if(structkeyexists(column, 'fields')){
							for(field in column.fields){
								if(structkeyexists(field, 'sortable') and field.sortable){
									echo('<a href="#variables.qSortCom.getColumnURL(field.field, currentLink)#">#field.label#</a> 
									#variables.qSortCom.getColumnIcon(field.field)#');
								}else{
									echo(field.label);
								} 
							}
						}else{
							if(structkeyexists(column, 'sortable') and column.sortable){
								echo('<a href="#variables.qSortCom.getColumnURL(column.field, currentLink)#">#column.label#</a> 
								#variables.qSortCom.getColumnIcon(column.field)#');
							}else{
								echo(column.label);
							} 
						}
						echo('</th>');
					} 
					</cfscript> 
				</tr>
				</thead>
				<tbody>
					<cfscript>
					rowCount=0;
					for(row in rs.qData){
						rowCount++;
						echo('<tr ');
						if(variables.rowSortingEnabled){
							echo(variables.queueSortCom.getRowHTML(row[variables.primaryKeyField]));
						} 
						if(rowCount MOD 2 EQ 0){
							echo(' class="row2"');
						}else{
							echo(' class="row1"');
						}
						echo('>');
						row.currentRow=rowCount;
						columns=[];
						request.zArrErrorMessages=["#variables.methods.getListRow# was called.  The error may be in this function."];
						variables[variables.methods.getListRow](row, columns);
						request.zArrErrorMessages=[];
						for(column in columns){
							echo('<td');
							if(structkeyexists(column, 'style')){
								echo(' style="#column.style#"');
							}
							if(structkeyexists(column, 'class')){
								echo(' class="#column.class#"');
							}
							echo('>#column.field#</td>');
						}
						echo('</tr>');
					}
					</cfscript> 
				</tbody>
			</table>
			<div class="z-manager-pagination" style=" border-top:none;">
				#searchNav#
			</div>
		</cfif>
	</div>

</cffunction> 


<!--- 
ts={
	links:[{
		label:"Edit Office",
		link:"/z/admin/new-interface/edit?office_id=#row.office_id#&modalpopforced=1",
		enableEditAjax:true // only possible for the link that replaces the current row
	},{
		label:"Manage Leads",
		link:"/z/inquiries/admin/manage-inquiries/index?search_office_id=#row.office_id#"
	},{
		title:"Edit",
		icon:"cog",
		label:"",
		links:[{
			label:"Edit",
			link:"##"
		}
		]
}
displayAdminEditMenu(ts);
 --->
<cffunction name="displayAdminMenu" localmode="modern" access="private">
	<cfargument name="ss" type="struct" required="yes">
	<cfscript>
	ss=arguments.ss;
	if(not structkeyexists(variables, 'editRowUniqueIndex')){
		variables.editRowUniqueIndex=0;
	} 
	ds={
		title:"",
		icon:"",
		link:"##",
		label:"",
		enableEditAjax:false
	};
	for(button in ss.buttons){ 
		structappend(button, ds, false);
		if(structkeyexists(button, 'links') and arraylen(button.links)){
			variables.editRowUniqueIndex++;
			echo('<div class="z-manager-button-container">
				<a href="##" class="z-manager-edit" id="z-manager-edit#variables.editRowUniqueIndex#" title="#htmleditformat(button.title)#"><i class="fa fa-cog" aria-hidden="true"></i></a>
				<div class="z-manager-edit-menu">');
			for(link in button.links){
				structappend(link, ds, false); 
				echo('<a href="#link.link#" ');
				if(structKeyExists(link, "enableEditAjax") and link.enableEditAjax){
					echo(' onclick="zTableRecordEdit(this);  return false;"');
				} 
				if(structkeyexists(link, 'target')){
					echo(' target="#link.target#"');
				}
				echo('>'&link.label&'</a>');
			}
			echo('</div>
			</div>');
		}else{
			echo('<div class="z-manager-button-container">');
			if(structKeyExists(button, "enableDeleteAjax") and button.enableDeleteAjax){
				echo('<a href="##" onclick="zDeleteTableRecordRow(this, ''#button.link#''); return false;">');
			}else{
				if(button.link NEQ ""){
					echo('<a href="#button.link#"');
					if(structKeyExists(button, "enableEditAjax") and button.enableEditAjax){
						echo(' onclick="zTableRecordEdit(this);  return false;"');
					}
					if(structkeyexists(button, 'target')){
						echo(' target="#button.target#"');
					}
				}else{
					echo('<div ');
				}
				echo(' class="z-manager-assign" title="#htmleditformat(button.title)#">');
			}
			if(button.icon NEQ ""){
				echo('<i class="fa fa-#button.icon#" aria-hidden="true"></i>');
			}
			if(button.label NEQ ""){
				echo('<span style="display:inline-block; padding-top:5px;">#button.label#</span>');
			}
			if(button.link NEQ ""){
				echo('</a>');
			}else{
				echo('</div>');
			}
			echo('
			</div>');
		}
	}
	</cfscript>
</cffunction>

<cffunction name="displayRowSortButton" localmode="modern" access="private">
	<cfargument name="id" type="string" required="yes">
	<cfscript>
	if(variables.rowSortingEnabled and variables.sortColumnSQL EQ ''){
		echo('<div class="z-manager-button-container">
			#variables.queueSortCom.getAjaxHandleButton(arguments.id)#
		</div>');
	}
	</cfscript>
</cffunction>


<cffunction name="delete" localmode="modern" access="private">
	<cfscript>
	init();
	var db=request.zos.queryObject; 
	
	request.zArrErrorMessages=["#variables.methods.getDeleteData# was called.  The error may be in this function."];
	rs=variables[variables.methods.getDeleteData]();
	request.zArrErrorMessages=[];
	if(not structkeyexists(rs, 'qData')){
		throw("variables.methods.getDeleteData function must return a struct with this format: { qData:qData }");
	}
	
	if(rs.qData.recordcount EQ 0){
		application.zcore.functions.zReturnJson({success:false, errorMessage:"#variables.label# doesn't exist."});
	} 
 

	if(variables.metaField NEQ ""){
		structappend(form, variables.metaCom.getData(variables.tableName, form), false); 
		rsDelete=variables.metaCom.delete(variables.tableName, form); 
		if(not rsDelete.success){
			application.zcore.functions.zReturnJson({success:false, errorMessage:rs.errorMessage});
		}
	}
	for(field in variables.imageLibraryFields){
		application.zcore.imageLibraryCom.deleteImageLibraryId(rs.qData[field]);
	}
	for(fs in variables.imageFields){ 
		if(structkeyexists(fs, 'originalField') and rs.qData[fs.originalField] NEQ ""){
			application.zcore.functions.zDeleteFile(fs.uploadPath&rs.qData[fs.originalField]);
		}
		if(rs.qData[fs.field] NEQ ""){
			application.zcore.functions.zDeleteFile(fs.uploadPath&rs.qData[fs.field]);
		}
	}  
	for(fs in variables.fileFields){
		if(rs.qData[fs.field] NEQ ""){
			application.zcore.functions.zDeleteFile(fs.uploadPath&rs.qData[fs.field]); 
		}
	}
 

	if(variables.methods.executeDelete NEQ ""){

		request.zArrErrorMessages=["#variables.methods.executeDelete# was called.  The error may be in this function."];
		rsDelete=variables[variables.methods.executeDelete]();
		request.zArrErrorMessages=[];
		if(not rsDelete.success){
			application.zcore.status.displayReturnJson(request.zsid);
		}
	}
	if(variables.rowSortingEnabled){
		variables.queueSortCom.sortAll();
	}
	application.zcore.functions.zReturnJson({success:true});
	</cfscript>
</cffunction>

<!--- <cffunction name="insert" localmode="modern" access="private">
	<cfscript>
	update();
	</cfscript>
</cffunction> --->
 
<cffunction name="update" localmode="modern" access="private">
	<cfscript>
	db=request.zos.queryObject;
	init();
	if(variables.disableAddEdit){
		application.zcore.functions.z404("Add/edit is disabled.");
	}
 
	ts=variables.validateFields;
	fail = application.zcore.functions.zValidateStruct(form, ts, request.zsid,true);

	rsInsert={success:true};
	rsUpdate={success:true};
	if(form.method EQ "update" and variables.methods.beforeUpdate NEQ ""){
		request.zArrErrorMessages=["#variables.methods.beforeUpdate# was called.  The error may be in this function."];
		rsUpdate=variables[variables.methods.beforeUpdate]();
		request.zArrErrorMessages=[];
	}
	if(form.method EQ "insert" and variables.methods.beforeInsert NEQ ""){
		request.zArrErrorMessages=["#variables.methods.beforeInsert# was called.  The error may be in this function."];
		rsInsert=variables[variables.methods.beforeInsert]();
		request.zArrErrorMessages=[];
	}
	if(not rsUpdate.success or not rsInsert.success){	
		application.zcore.status.displayReturnJson(request.zsid);
	}   

	if(variables.metaField NEQ ""){
		arrError=variables.metaCom.validate(variables.tableName, form);
		if(arrayLen(arrError)){
			fail=true;
			for(e in arrError){
				application.zcore.status.setStatus(request.zsid, e, form, true);
			}
		}
	}
	
	if(form.method EQ "update"){
		if(variables.methods.beforeUpdate NEQ ""){
			if(not structkeyexists(rsUpdate, 'qData')){
				throw("variables.methods.beforeUpdate function must return a struct with this structure: {success:true, qData:qData} ");
			}
		}
	} 
	for(fs in variables.imageFields){
		application.zcore.functions.zCreateDirectory(fs.uploadPath);

		deleting=false;
		if(application.zcore.functions.zso(form, "#fs.field#_delete") NEQ ""){
			if(structkeyexists(fs, 'originalField')){
				application.zcore.functions.zDeleteFile(fs.uploadPath&rsUpdate.qData[fs.originalField]);
				form["#fs.field#_original"]="";
			}
			application.zcore.functions.zDeleteFile(fs.uploadPath&rsUpdate.qData[fs.field]);
			form[fs.field]="";
			deleting=true;
		}
		if(application.zcore.functions.zso(form, fs.field) NEQ ""){
			// the empty strings are because we want to delete the original above.
			arrList = application.zcore.functions.zUploadResizedImagesToDb(fs.field, fs.uploadPath, fs.size, "","","", variables.datasource, fs.crop, request.zos.globals.id, false);
			if(isarray(arrList) EQ false){
				fail=true;
				application.zcore.status.setStatus(request.zsid, "<strong>PHOTO ERROR:</strong> invalid format or corrupted.  Please upload a jpeg, png or gif file.<br />"&request.zImageErrorCause, form, true);
			}else if(ArrayLen(arrList) NEQ 0){
				if(structkeyexists(fs, 'originalField')){
					form[fs.originalField]=request.zos.lastUploadFileName; 
				}
				form[fs.field]=arrList[1];
			}
		}else if(form.method EQ "update" and not deleting){
			if(structkeyexists(fs, 'originalField')){
				form[fs.originalField]=rsUpdate.qData[fs.originalField];
			}
			form[fs.field]=rsUpdate.qData[fs.field];
		}
	} 

	if(fail){	
		application.zcore.status.displayReturnJson(request.zsid);
	} 
	if(variables.metaField NEQ ""){
		form[variables.metaField]=variables.metaCom.save(variables.tableName, form); 
	}

	for(fs in variables.fileFields){
		application.zcore.functions.zCreateDirectory(fs.uploadPath);
		deleting=false;
		if(application.zcore.functions.zso(form, "#fs.field#_delete") NEQ ""){
			application.zcore.functions.zDeleteFile(fs.uploadPath&rsUpdate.qData[fs.field]); 
			form[fs.field]="";
			deleting=true;
		}
		if(application.zcore.functions.zso(form, fs.field) NEQ ""){
			form[fs.field]=application.zcore.functions.zUploadFileToDb(fs.field, fs.uploadPath, variables.tableName, variables.primaryKeyField, application.zcore.functions.zso(form, "#fs.field#_delete", true, 0), variables.datasource); 
		}else if(form.method EQ "update" and not deleting){ 
			form[fs.field]=rsUpdate.qData[fs.field];
		}
	}
	ts=StructNew();
	ts.table=variables.tableName;
	ts.datasource=variables.datasource;
	ts.struct=form;

	newRecord=false;

	if(form.method EQ 'insert'){
		newRecord=true;
		if(not variables.customInsertUpdate){
			form[variables.primaryKeyField] = application.zcore.functions.zInsert(ts);
			if(form[variables.primaryKeyField] EQ false){
				application.zcore.status.setStatus(request.zsid, 'Failed to save #variables.label#.',form,true);
				application.zcore.status.displayReturnJson(request.zsid); 
			}else{
				application.zcore.status.setStatus(request.zsid, '#variables.label# saved.');
			}
		}
		if(variables.methods.afterInsert NEQ ""){
			request.zArrErrorMessages=["#variables.methods.afterInsert# was called.  The error may be in this function."];
			rs=variables[variables.methods.afterInsert]();
			request.zArrErrorMessages=[];
			if(not rs.success){
				application.zcore.status.displayReturnJson(request.zsid);
			}
		}
		if(variables.rowSortingEnabled){
			variables.queueSortCom.sortAll();
		}
	}else{
		if(not variables.customInsertUpdate){
			if(application.zcore.functions.zUpdate(ts) EQ false){
				application.zcore.status.setStatus(request.zsid, 'Failed to save #variables.label#.',form,true);
				application.zcore.status.displayReturnJson(request.zsid);
			}else{
				application.zcore.status.setStatus(request.zsid, '#variables.label# updated.');
			}
		}
		if(variables.methods.afterUpdate NEQ ""){
			request.zArrErrorMessages=["#variables.methods.afterUpdate# was called.  The error may be in this function."];
			rs=variables[variables.methods.afterUpdate]();
			request.zArrErrorMessages=[];
			if(not rs.success){
				application.zcore.status.displayReturnJson(request.zsid);
			}
		}
	}

	if(arrayLen(variables.imageLibraryFields)){
		for(field in variables.imageLibraryFields){
			application.zcore.imageLibraryCom.activateLibraryId(application.zcore.functions.zso(form, field));
		}
	}
	rowHTML=returnRow();
	application.zcore.functions.zReturnJson({success:true, id:form[variables.primaryKeyField], rowHTML:rowHTML, newRecord:newRecord});
	</cfscript>
</cffunction>


<cffunction name="returnRow" localmode="modern" access="private" returntype="string">
	<cfscript>
	if(variables.columnSortingEnabled){
		variables.sortColumnSQL=variables.qSortCom.getorderby(false);  
		if(variables.sortColumnSQL NEQ ""){
			arrayAppend(variables.titleLinks, {
				link:variables.prefixURL&"index",
				text:"Clear Sorting"
			});
		}
	}
	request.zArrErrorMessages=["#variables.methods.getListReturnData# was called.  The error may be in this function."];
	rs=variables[variables.methods.getListReturnData](); 
	request.zArrErrorMessages=[];
	if(not structkeyexists(rs, 'qData')){
		throw("variables.methods.getListReturnData function must return a struct like: {qData:qData}");
	} 
	columns=[];
	savecontent variable="out"{
		for(row in rs.qData){
			request.zArrErrorMessages=["#variables.methods.getListRow# was called.  The error may be in this function."];
			variables[variables.methods.getListRow](row, columns);
			variables.methods.getListRow=[];
			for(column in columns){
				echo('<td');
				if(structkeyexists(column, 'style')){
					echo(' style="#column.style#"');
				}
				if(structkeyexists(column, 'class')){
					echo(' class="#column.class#"');
				}
				echo('>#column.field#</td>');
			}
		}
	}
	return out;
	</cfscript>
</cffunction>
 

<cffunction name="edit" localmode="modern" access="private">
	<cfscript>
	var db=request.zos.queryObject;
	init();
	var currentMethod=form.method;
	if(variables.disableAddEdit){
		application.zcore.functions.z404("Add/edit is disabled.");
	}

	form.modalpopforced=application.zcore.functions.zso(form, "modalpopforced",true, 0);
	if(form.modalpopforced EQ 1){
		application.zcore.skin.includeCSS("/z/a/stylesheets/style.css");
		application.zcore.functions.zSetModalWindow();
	}
	if(currentMethod EQ "add"){
		form[variables.primaryKeyField]=0;
		if(form.modalpopforced EQ 0){
			application.zcore.functions.zRedirect(variables.prefixURL&"index?zManagerAddOnLoad=1");
		}
	}
	request.zArrErrorMessages=["#variables.methods.getEditData# was called.  The error may be in this function."];
	rs=variables[variables.methods.getEditData](); 
	request.zArrErrorMessages=[];
	if(not structkeyexists(rs, 'qData')){
		throw("variables.methods.getEditData function must return a struct like: {qData:qData}");
	} 


	echo('<div class="z-manager-edit-head">');
	if(currentMethod EQ "add"){
		echo('<h2>Add #variables.label#</h2>');
		application.zcore.functions.zCheckIfPageAlreadyLoadedOnce();
		formAction="#variables.prefixURL#insert?#variables.requiredParamsQS#";
		application.zcore.functions.zQueryToStruct(rs.qData); 
	}else{
		if(rs.qData.recordcount EQ 0){
			application.zcore.status.setStatus(request.zsid, "#variables.label# doesn't exist.", form, true);
			application.zcore.functions.zRedirect("#variables.prefixURL#index?#variables.requiredParamsQS#&zsid=#request.zsid#");
		}
		echo('<h2>Edit #variables.label#</h2>');
		formAction="#variables.prefixURL#update?#variables.primaryKeyField#=#urlencodedformat(form[variables.primaryKeyField])#&#variables.requiredParamsQS#";
		for(row in rs.qData){
			structappend(form, row, false);
		}
	}
	if(variables.metaField NEQ ""){
		structappend(form, variables.metaCom.getData(variables.tableName, form), false); 
	}

	echo('<div class="z-mb-10">* = required field</div>');
	echo('</div>');
	application.zcore.functions.zStatusHandler(request.zsid,true); 
 
	request.zArrErrorMessages=["#variables.methods.getEditForm# was called.  The error may be in this function."];
	rsEditForm=variables[variables.methods.getEditForm](); 
	request.zArrErrorMessages=[];
	// loop everything here 

	echo('
	<div class="z-manager-edit-errors z-float"></div>
	<form id="zManagerEditForm" class="zFormCheckDirty" action="#formAction#" method="post" enctype="multipart/form-data" onsubmit="return zSubmitManagerEditForm(); ">');
	/*
	ts=StructNew();
	ts.name="zMLSSearchForm";
	ts.ajax=false; 
	ts.class="zFormCheckDirty";
	ts.enctype="multipart/form-data";
	ts.action=formAction;
	ts.method="post";
	ts.successMessage=false;
	if(rsEditForm.javascriptLoadCallback NEQ ""){
		ts.onLoadCallback=rsEditForm.javascriptLoadCallback;
	}
	if(rsEditForm.javascriptChangeCallback NEQ ""){
		ts.onChangeCallback=rsEditForm.javascriptChangeCallback;
	}
	application.zcore.functions.zForm(ts);
	*/
	  
	tabCom=application.zcore.functions.zcreateobject("component","zcorerootmapping.com.display.tab-menu");
	tabCom.init();
	tabs=[];
	for(tab in rsEditForm.tabs){
		arrayAppend(tabs, tab);
	}
	tabCom.setTabs(tabs); 
	tabCom.setMenuName("member-#application.zcore.functions.zURLEncode(lcase(variables.label), "-")#-edit");
	cancelURL=application.zcore.functions.zso(request.zsession, variables.primaryKeyField&'_return'&form[variables.primaryKeyField]); 
	if(cancelURL EQ ""){
		cancelURL="#variables.prefixURL#index?#variables.requiredParamsQS#";
	}
	tabCom.setCancelURL(cancelURL);
	tabCom.enableSaveButtons();
	if(form.modalpopforced EQ 1){
		echo('
		<script type="text/javascript">
		zArrDeferredFunctions.push(function(){
			$(".tabCancelButton").on("click", function(e){
				e.preventDefault();
				window.parent.zCloseModal();
				return false;
			});
		});
		</script>
		');
	} 
	echo(tabCom.beginTabMenu());
	for(tab in rsEditForm.tabs){
		echo(tabCom.beginFieldSet(tab));
		if(not structkeyexists(rsEditForm.tabs, tab)){
			rsEditForm.tabs[tab]={fields:[]}; 
		}
		if(variables.metaField NEQ ""){
			metaFields=variables.metaCom.displayForm(variables.tableName, tab, "first", true);
			if(arraylen(metaFields)){ 
				for(i=arraylen(metaFields);i>=1;i--){
					arrayPrepend(rsEditForm.tabs[tab].fields, metaFields[i]);
				}
			}
			metaFields=variables.metaCom.displayForm(variables.tableName, tab, "last", true);
			if(arraylen(metaFields)){ 
				for(i=1;i<=arraylen(metaFields);i++){
					arrayAppend(rsEditForm.tabs[tab].fields, metaFields[i]);
				}
			}
		}
		if(structkeyexists(rsEditForm.tabs, tab)){
			echo('<table style="width:100%;" class="table-list">');
			for(field in rsEditForm.tabs[tab].fields){
				echo('<tr>
					<th>#field.label#');
				if(structkeyexists(field, 'required') and field.required){
					echo(' *');
				}

				echo('</th>
					<td>#field.field#</td>
				</tr>');
			}
			echo('</table>');
		}
		echo(tabCom.endFieldSet());
	}
	echo(tabCom.endTabMenu());
	echo('</form>');
	//echo(application.zcore.functions.zEndForm());
	</cfscript>  
	<script type="text/javascript">
	</script>
</cffunction>

</cfoutput>
</cfcomponent>