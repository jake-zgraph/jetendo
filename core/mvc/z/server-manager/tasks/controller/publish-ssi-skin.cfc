<cfcomponent>
<cfoutput>
<cffunction name="index" localmode="modern" access="remote">
	<cfscript>
	var r1=0;
	var db=request.zos.queryObject;
	var qC=0;
	var a1=0;
	var r1=0;
	
	if(not request.zos.isDeveloper and not request.zos.isServer and not request.zos.isTestServer){
		application.zcore.functions.z404("Can't be executed except on test server or by server/developer ips.");
	}
	request.ignoreSlowScript=true;
	setting requesttimeout="5000";
	db.sql="select site.site_id, site_domain, site_enable_ssi_publish
	from #request.zos.queryObject.table("site", request.zos.zcoreDatasource)# site
	where site.site_active =#db.param('1')# ";
	qC=db.execute("qC");
	// later loop all domains with this feature enabled in server manager.
	loop query="qC"{
		if(qC.site_enable_ssi_publish EQ 1){
			r1=application.zcore.functions.zdownloadlink(qC.site_domain&"/z/admin/ssi-skin/taskPublish");
			if(r1.success){
				writeoutput(r1.cfhttp.FileContent);
			}else{
				writeoutput('<h2>Failed to publish ssi skin</h2>');
				writedump(r1.cfhttp);
			}
		}
	}
	writeoutput('Done');
	abort;
	</cfscript>
</cffunction>
</cfoutput>
</cfcomponent>