<!-----------------------------------------------------------------------
Author 	 :	Devon Burriss
Date     :	11/30/2010
Description : 			
 Empty Interceptor
		
Modification History:

----------------------------------------------------------------------->
<cfcomponent name="SynapseInterceptor"  hint="" output="false">
  
<!------------------------------------------- PUBLIC ------------------------------------------->	 	

   
    <cffunction name="configure" access="public" returntype="void" output="false" hint="Configure your interceptor">
		
	</cffunction>
	<!--- SAVE --->
	<cffunction name="beforeSynapseSave" access="public" returntype="Boolean" output="false" hint="I run before an entity is persisted">
		<cfset this.doLog('INTERCEPTOR/beforeSynapseSave:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseSaveTransaction" access="public" returntype="Boolean" output="false" hint="I run after an entity save transaction completes">
		<cfset this.doLog('INTERCEPTOR/afterSynapseSaveTransaction:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseSave" access="public" returntype="Boolean" output="false" hint="I run after an entity is persisted">
		<cfset this.doLog('INTERCEPTOR/afterSynapseSave:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	<!--- CREATE --->
	<cffunction name="beforeSynapseCreate" access="public" returntype="Boolean" output="false" hint="I run before an entity is created">
		<cfset this.doLog('INTERCEPTOR/beforeSynapseCreate:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseCreateTransaction" access="public" returntype="Boolean" output="false" hint="I run after an entity create transaction completes">
		<cfset this.doLog('INTERCEPTOR/afterSynapseCreateTransaction:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseCreate" access="public" returntype="Boolean" output="false" hint="I run after an entity is created">
		<cfset this.doLog('INTERCEPTOR/afterSynapseCreate:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<!--- UPDATE --->
	<cffunction name="beforeSynapseUpdate" access="public" returntype="Boolean" output="false" hint="I run before an entity is updated">
		<cfset this.doLog('INTERCEPTOR/beforeSynapseUpdate:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseUpdateTransaction" access="public" returntype="Boolean" output="false" hint="I run after an entity update transaction completes">
		<cfset this.doLog('INTERCEPTOR/afterSynapseUpdateTransaction:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseUpdate" access="public" returntype="Boolean" output="false" hint="I run after an entity is updated">
		<cfset this.doLog('INTERCEPTOR/afterSynapseUpdate:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<!--- DELETE --->
	<cffunction name="beforeSynapseDelete" access="public" returntype="Boolean" output="false" hint="I run before an entity is deleted">
		<cfset this.doLog('INTERCEPTOR/beforeSynapseDelete:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseDeleteTransaction" access="public" returntype="Boolean" output="false" hint="I run after an entity delete transaction completes">
		<cfset this.doLog('INTERCEPTOR/afterSynapseDeleteTransaction:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseDelete" access="public" returntype="Boolean" output="false" hint="I run after an entity is deleted">
		<cfset this.doLog('INTERCEPTOR/afterSynapseDelete:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<!--- LOAD --->
	<cffunction name="beforeSynapseLoad" access="public" returntype="Boolean" output="false" hint="I run before an entity is loaded">
		<cfset this.doLog('INTERCEPTOR/beforeSynapseLoad:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseLoadTransaction" access="public" returntype="Boolean" output="false" hint="I run after an entity load transaction completes">
		<cfset this.doLog('INTERCEPTOR/afterSynapseLoadTransaction:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseLoad" access="public" returntype="Boolean" output="false" hint="I run after an entity is loaded">
		<cfset this.doLog('INTERCEPTOR/afterSynapseLoad:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
    
	<!--- POPULATE --->
	<cffunction name="beforeSynapsePopulate" access="public" returntype="Boolean" output="false" hint="I run before an entity is populated">
		<cfargument name="memento" required="true" type="Struct">
		
		<cfset this.doLog('INTERCEPTOR/beforeSynapsePopulate:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapsePopulate" access="public" returntype="Boolean" output="false" hint="I run after an entity is populated">
		<cfargument name="memento" required="true" type="Struct">
		
		<cfset this.doLog('INTERCEPTOR/afterSynapsePopulate:#this.getAlias()#')>
		<cfreturn true>
	</cffunction>
	
	<!--- MUTATE --->
	<cffunction name="beforeSynapseMutate" access="public" returntype="Boolean" output="false" hint="I run before an entity value is changed/mutated">
		<cfargument name="property" required="true" type="String">
		<cfargument name="value" required="true" type="Any">
		<!--- turned off logging for this coz to much overhead --->
		<!--- <cfset this.doLog('INTERCEPTOR/beforeSynapseMutate:#this.getAlias()#')> --->
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseMutate" access="public" returntype="Boolean" output="false" hint="I run after an entity value is changed/mutated">
		<cfargument name="property" required="true" type="String">
		<cfargument name="value" required="true" type="Any">
		<!--- turned off logging for this coz to much overhead --->
		<!--- <cfset this.doLog('INTERCEPTOR/afterSynapseMutate:#this.getAlias()#')> --->
		<cfreturn true>
	</cffunction>
	
	<!--- ACCESS --->
	<cffunction name="beforeSynapseAccess" access="public" returntype="Boolean" output="false" hint="I run before an entity is accessed for a value">
		<cfargument name="property" required="true" type="String">
		<!--- turned off logging for this coz to much overhead --->
		<!--- <cfset this.doLog('INTERCEPTOR/beforeSynapseAccess:#this.getAlias()#')> --->
		<cfreturn true>
	</cffunction>
	
	<cffunction name="afterSynapseAccess" access="public" returntype="Boolean" output="false" hint="I run after an entity is accessed for a value">
		<cfargument name="property" required="true" type="String">
		<!--- turned off logging for this coz to much overhead --->
		<!--- <cfset this.doLog('INTERCEPTOR/afterSynapseAccess:#this.getAlias()#')> --->
		<cfreturn true>
	</cffunction>

<!------------------------------------------- PRIVATE ------------------------------------------->	 	


</cfcomponent>