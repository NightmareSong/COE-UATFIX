public without sharing class TGS_fill_CSUID {
/*-------------------------------------------------------------------------------------------------------------------------------------------------------
    Author:        Miguel Angel Galindo
    Company:       Deloitte
    Description:   

    History

    <Date>            <Author>                      <Description>
    06/08/2015        Miguel Angel Galindo          Initial version
    31/09/2015        Luis Miguel Alonso            Comment and fixed. It doesn't work before
    23/11/2015        Luis Miguel Alonso            Add NE__AssetItemEnterpriseId__c condition
    24/11/2015        Luis Miguel Alonso            If order type is Termination, create news CSUIDs
                                                    If MRC or NRC prices change, old csuid must change too.
    19/05/2016        Fernando Arteaga              Copy CSUIDs from the order into the asset
    02/06/2016        Fernando Arteaga              Don't fill CSUID Old fields and dont't copy CSUIDs into the asset for modifications/terminations
    15/06/2016        Fernando Arteaga              Generate unique CSUIDs. For GM modification orders, don't generate new CSUIDs, copy the old ones
    07/07/2016        Patricia Castillo             Copy CSUIDs into the asset for modifications/terminations if mWan product
    12/07/2016        Patricia Castillo             Fix to copy CSUIDs old into the asset for modifications/terminations if mWan product
    13/07/2016        Patricia Castillo             Fix to update CSUIDs into the asset for modifications/terminations if mWan product
    14/07/2016        Juan Carlos Terrón            Línea 62 modify SOQL
    18/07/2016        Patricia Castillo             Add condition to avoid null pointer exception when an unsuscription mWan order is being managed
    15/06/2016        Juan Carlos Terrón            Added fill_CSUID_EnterpriseID method and it's child methods. Starts at line 289.
    24/06/2016        Juan Carlos Terrón            Deleted some fill_CSUID_EnterpriseID methods in order to remake them.
    25/06/2016        Juan Carlos Terrón            Added new functionality to fill_CSUID_EnterpriseID methods,also have renamed the parent method to fill_EnterpriseID.    
    27/06/2016        Juan Carlos Terrón            Changed csuid method parameters to addmit a map with the Asset asociated to its Case in order to get its Id to generates CSUID.
    29/09/2016        Juan Carlos Terrón            Replaced the commented code from line 124 to line 229 for the new code between lines 230-352. Also Added some debug sentences. 
    30/09/2016        Juan Carlos Terrón            Comented Lines 252 253.
                                                    Added Values to BillableATTR map.   
--------------------------------------------------------------------------------------------------------------------------------------------------------*/


    public static void csuid (Case myCaseAsset, Map<String,NE__Order__c> map_CASEID_ASSET){
        //Método para rellenar todos los CSUID nuevos y antiguos de los Order correspondientes al asset
        System.debug('#### New Asset: '+ myCaseAsset.asset__c);
        Id AUX_ASSETID;
        /*JCT 27/06/2016 Added myCaseAsset.asset__c null checking also added an aux variable declaration to store de Asset Id.*/
        /*JCT 29/09/2016 Changed myCaseAsste.asset__c checking to be under listCases declaration.*/
        // Obtengo todas los cases que tienen el asset newAsset.Id
        List<Case> listCases = [Select Order__c, Order__r.NE__Asset__c
                               From Case
                               WHERE Id = :myCaseAsset.Id
                               Order by CreatedDate DESC LIMIT 1]; //FAR 02/06/2016 - Added order by and limit 
                               // JCT 29/09/2016 - Changed from  Where Asset__c = :AUX_ASSETID to WHERE Asset__c = myCaseAsset.Id
        if(myCaseAsset.asset__c==null){
              AUX_ASSETID = map_CASEID_ASSET.get(String.valueOf(listCases.get(0).Order__r.NE__Asset__c)).Id;
        }
        else
        {
            AUX_ASSETID = myCaseAsset.asset__c;
        }
        // Obtengo recordType del tipo Assert
        Id rtIDAss = TGS_RecordTypes_Util.getRecordTypeId(NE__Order__c.SObjectType, 'Asset');        
        // Obtengo recordType del tipo Order
        Id rtIdO = TGS_RecordTypes_Util.getRecordTypeId(NE__Order__c.SObjectType, 'Order');        
        // Inicializamos los Items a actualizar
        Set<NE__OrderItem__c> setOiUpdate = new Set<NE__OrderItem__c>();
        Set<NE__Order_Item_Attribute__c> setOiAttributeUpdate = new Set<NE__Order_Item_Attribute__c>();     
        
        // FAR 19/05/2016
        Map<String, List<String>> mapCSUID = new Map<String, List<String>>();
        Map<String, List<String>> mapCSUID_Attr = new Map<String, List<String>>(); // FAR 02/06/2016
        Map<Id, NE__OrderItem__c> mapCiOrder = new Map<Id, NE__OrderItem__c>();
        Map<Id, List<NE__Order_Item_Attribute__c>> mapCiOrderAttributes = new Map<Id, List<NE__Order_Item_Attribute__c>>();
        Map<Id, List<NE__Order_Item_Attribute__c>> mapCiAssetAttributes = new Map<Id, List<NE__Order_Item_Attribute__c>>();
        Map<Id,NE__Order_Item_Attribute__c> map_AllATTR = new Map<Id,NE__Order_Item_Attribute__c>();
        Set<Id> setCIsGM = new Set<Id>();
        // END FAR 19/05/2016
        Set<String> set_BillableATTR = new Set<String>{'Bundle Selection','White List Selection','Model Number','DEVICE Status','Insurance Device Service','Model Number','Mobile Intranet CPE Connection','Mobile Intranet CPE Maintenance service','Mobile Intranet APN Aunthentication','Mobile Intranet CPE Contract Modality','Mobile Intranet Configuration Services','Pooling Bundle','Bundle','Special Number','DDI Standard','Special Number','DDI Standard','FLAT RATE','CommonName','RoutingProfile'};
        // Ids de los orders que posee en cada case
        Set<Id> listOrder = new Set<Id>{};
        for(Case myCase : listCases){
            listOrder.add(myCase.Order__c);
        }
        // Obtengo los items de las configuraciones del tipo asset
        // FAR 19/05/2016 - Fill CSUIDs in asset order items 
        List<NE__OrderItem__c> listCiAsset = [SELECT Id, Name, TGS_CSUID1__c, TGS_CSUID2__c, TGS_CSUID1_Old__c, TGS_CSUID2_Old__c, NE__AssetItemEnterpriseId__c
                                              FROM NE__OrderItem__c 
                                              WHERE isDeleted = false
                                              AND NE__OrderId__c = :AUX_ASSETID
                                              FOR UPDATE];
        System.debug('#16# Lista CI de Asset '+listCiAsset.size());
        mapCiOrder = new Map<Id, NE__OrderItem__c>([SELECT Name, TGS_CSUID1__c, TGS_CSUID2__c, Id, TGS_CSUID1_Old__c, TGS_CSUID2_Old__c, NE__OrderId__c, NE__OrderId__r.Case__c,
                                                            NE__Action__c, TGS_Change_MRC__c , TGS_Change_NRC__c, TGS_Attributes_modified__c, NE__OrderId__r.Case__r.TGS_Service__c,
                                                            TGS_Flag_Update_msg__c, NE__AssetItemEnterpriseId__c, NE__OrderId__r.NE__Configuration_Type__c,
                                                            NE__ProdId__r.TGS_CWP_Tier_2__c
                                                    FROM NE__OrderItem__c 
                                                    WHERE isDeleted = false
                                                    AND NE__OrderId__c = :myCaseAsset.Order__c
                                                    FOR UPDATE]);
        System.debug('#16# Mapa de CI de Order '+mapCiOrder.size());
        // Obtengo los items de las configuraciones del tipo order
        for (NE__Order_Item_Attribute__c attr: [SELECT Id, TGS_CSUID__c, TGS_CSUID2__c, TGS_CSUID_Old__c, TGS_CSUID2_Old__c, NE__AttrEnterpriseId__c,
                                                        NE__Order_Item__c, Name, NE__Value__c, NE__Old_Value__c, TGS_Flag_Update_msg__c, TGS_Product_name__c 
                                                FROM NE__Order_Item_Attribute__c 
                                                WHERE isDeleted = false
                                                AND NE__Order_Item__c IN :mapCiOrder.values()
                                                ORDER BY CreatedDate ASC])
        {
            if (!mapCiOrderAttributes.containsKey(attr.NE__Order_Item__c)){
                mapCiOrderAttributes.put(attr.NE__Order_Item__c, new List<NE__Order_Item_Attribute__c>{attr});
                map_AllATTR.put(attr.Id, attr);}
            else{
                mapCiOrderAttributes.get(attr.NE__Order_Item__c).add(attr);
                map_AllATTR.put(attr.Id, attr);}
        }
        
        // Obtiene los atributos de los items de las configuraciones del tipo asset
        for (NE__Order_Item_Attribute__c attr: [SELECT Id, Name, NE__Order_Item__c, TGS_CSUID__c, TGS_CSUID2__c, NE__AttrEnterpriseId__c
                                                FROM NE__Order_Item_Attribute__c
                                                WHERE isDeleted = false AND NE__Order_Item__c IN :listCiAsset
                                                ORDER BY CreatedDate ASC])
        {
            if (!mapCiAssetAttributes.containsKey(attr.NE__Order_Item__c)){
                mapCiAssetAttributes.put(attr.NE__Order_Item__c, new List<NE__Order_Item_Attribute__c>{attr});
                map_AllATTR.put(attr.Id, attr);
            }
            else{
                mapCiAssetAttributes.get(attr.NE__Order_Item__c).add(attr);
                map_AllATTR.put(attr.Id, attr);
            }
        }
            
        for(NE__OrderItem__c ciAsset : listCiAsset)
        {
            /*System.debug(LoggingLevel.ERROR, 'ciAsset:' + ciAsset.Name);
            System.debug(LoggingLevel.ERROR, 'ciAsset.Id:' + ciAsset.Id);
            System.debug(LoggingLevel.ERROR, 'ciAsset.NE__AssetItemEnterpriseId__c:' + ciAsset.NE__AssetItemEnterpriseId__c);

            NE__OrderItem__c ciOrder = mapCiOrder.get(ciAsset.NE__AssetItemEnterpriseId__c);
            System.debug('#16# ciOrder '+mapCiOrder.get(ciAsset.NE__AssetItemEnterpriseId__c));
            System.debug('#16# mapa de los CI Order' + mapCiOrder);
            //PCP 18/07/2016 - Add condition to avoid null pointer exception when an unsuscription mWan order is being managed
            if(ciOrder != null) {
                System.debug(LoggingLevel.ERROR, 'ciOrder:' + ciOrder);
                System.debug('#######################' + ciOrder);
                    
                Integer lengthNameAsset = ciAsset.Name.length();
                String id_Order = ciOrder.NE__OrderId__c;
                
                // Creamos los nuevos codigos csuid    
                String AssetId = ciAsset.Name.substring(lengthNameAsset-6);
                String OrderId = id_Order.substring(11,15);
                
                if (ciOrder.TGS_CSUID1__c == null)
                {
                    // Global Mobility for MNCs for modification orders -> Don't generate a new CSUID, copy the CSUID Old
                    if (ciOrder.NE__ProdId__r.TGS_CWP_Tier_2__c != null &&
                        ciOrder.NE__ProdId__r.TGS_CWP_Tier_2__c.equals(Constants.GLOBAL_MOBILITY_FOR_MNCS) &&
                        ciOrder.NE__OrderId__r.NE__Configuration_Type__c == Constants.TYPE_CHANGE)
                    {
                        if (ciOrder.NE__Action__c != null && !ciOrder.NE__Action__c.equals(Constants.CI_ACTION_ADD)) {
                            ciOrder.TGS_CSUID1__c = ciOrder.TGS_CSUID1_Old__c;
                            ciOrder.TGS_CSUID2__c = ciOrder.TGS_CSUID2_Old__c;
                            setCIsGM.add(ciOrder.Id);
                            System.debug(LoggingLevel.ERROR, 'copiar old' + ciOrder.Name);
                        } else {
                            ciOrder.TGS_CSUID1__c = AssetId+'-'+OrderId+'-'+'1';
                            ciOrder.TGS_CSUID2__c = AssetId+'-'+OrderId+'-'+'2';
                        }
                    }
                    else
                    {
                        //PCP 07/07/2016 - Generate CSUIDs for new CIs (New or Change orders), or in mWan/mWan - Internet terminations
                        if (!ciOrder.NE__Action__c.equals(Constants.CI_ACTION_REMOVE) ||
                            (ciOrder.NE__Action__c.equals(Constants.CI_ACTION_REMOVE) && (ciOrder.NE__OrderId__r.Case__r.TGS_Service__c.equals(Constants.PRODUCT_MWAN_SU) || ciOrder.NE__OrderId__r.Case__r.TGS_Service__c.equals(Constants.PRODUCT_MWAN_INTERNET))))
                        {
                            ciOrder.TGS_CSUID1__c = AssetId+'-'+OrderId+'-'+'1';
                            ciOrder.TGS_CSUID2__c = AssetId+'-'+OrderId+'-'+'2';
                        }
                    }
                    
                    System.debug(LoggingLevel.ERROR, 'ciOrder.TGS_CSUID1__c: ' + ciOrder.TGS_CSUID1__c);
                    System.debug(LoggingLevel.ERROR, 'ciOrder.TGS_CSUID2__c: ' + ciOrder.TGS_CSUID2__c);
                    
                    if (!setOiUpdate.contains(ciOrder))
                        setOiUpdate.add(ciOrder);
                        
                    // FAR 02/06/2016 - Dont't copy CSUIDs into the asset for modifications/terminations
                    // PCP 12/07/2016 - Add to CSUIDs list old values too
                    // PCP 13/07/2016 - Add to CSUIDs list values to update asset CIs for mWan/mWan - Internet, regardless of kind of order
                    //if (ciOrder.NE__OrderId__r.NE__Configuration_Type__c == Constants.TYPE_NEW)
                    if (ciOrder.NE__Action__c != null && ciOrder.NE__Action__c.equals(Constants.CI_ACTION_ADD) ||
                        ciOrder.NE__Action__c!= null && (ciOrder.NE__OrderId__r.Case__r.TGS_Service__c.equals(Constants.PRODUCT_MWAN_SU) || ciOrder.NE__OrderId__r.Case__r.TGS_Service__c.equals(Constants.PRODUCT_MWAN_INTERNET))
                        )                   
                    {
                        mapCSUID.put(ciOrder.Id, new List<String>{ciOrder.TGS_CSUID1__c, ciOrder.TGS_CSUID2__c, ciOrder.TGS_CSUID1_old__c, ciOrder.TGS_CSUID2_old__c});
                    }
                    mapCSUID.put(ciOrder.Id, new List<String>{ciOrder.TGS_CSUID1__c, ciOrder.TGS_CSUID2__c, ciOrder.TGS_CSUID1_old__c, ciOrder.TGS_CSUID2_old__c});
                }
                
                // Insertamos tambien el csuid y csuid_old de los atributos
                if (mapCiOrderAttributes.containsKey(ciOrder.Id))
                {
                    for (NE__Order_Item_Attribute__c attribute : mapCiOrderAttributes.get(ciOrder.Id))
                    {
                        String idAttribute = attribute.Id;                                
                        String attributeId = idAttribute.substring(11,15);
                        
                        if (attribute.TGS_CSUID__c == null)
                        {
                            // Global Mobility for MNCs for modification orders -> Don't generate a new CSUID, copy the CSUID Old
                            if (setCIsGM.contains(attribute.NE__Order_Item__c))
                            {
                                System.debug(LoggingLevel.ERROR, 'copiar old (attribute): ' + attribute.Name + ', CI:' + ciOrder.Name);
                                attribute.TGS_CSUID__c = attribute.TGS_CSUID_Old__c;
                                attribute.TGS_CSUID2__c = attribute.TGS_CSUID2_Old__c;
                            }
                            //PCP 07/07/2016 - Generate CSUIDs for new CI attributes (New or Change orders), or in mWan/mWan - Internet terminations
                            //PCP 13/07/2016 - Add condition to allow mWan and children CIs attributes get generated CSUIDs
                            else if (!ciOrder.NE__Action__c.equals(Constants.CI_ACTION_REMOVE) ||
                                    (ciOrder.NE__Action__c.equals(Constants.CI_ACTION_REMOVE) && (ciOrder.NE__OrderId__r.Case__r.TGS_Service__c.equals(Constants.PRODUCT_MWAN_SU) || ciOrder.NE__OrderId__r.Case__r.TGS_Service__c.equals(Constants.PRODUCT_MWAN_INTERNET)))
                                    )
                            {
                                attribute.TGS_CSUID__c = AssetId + '-' + OrderId + '-' + attributeId;
                                attribute.TGS_CSUID2__c = attribute.TGS_CSUID__c + 'M';
                            }
                            
                            //if (!mapCSUID_Attr.containsKey(attribute.Id) && ciOrder.NE__OrderId__r.NE__Configuration_Type__c == Constants.TYPE_NEW)
                            //PCP 13/07/2016 - Add condition to allow mWan and children CIs attributes generated CSUIDs be kept into a map to be updated in asset CIs
                            if  (!mapCSUID_Attr.containsKey(attribute.Id) && ciOrder.NE__Action__c != null && ciOrder.NE__Action__c.equals(Constants.CI_ACTION_ADD) ||
                                (!ciOrder.NE__Action__c.equals(Constants.CI_ACTION_ADD) && (ciOrder.NE__OrderId__r.Case__r.TGS_Service__c.equals(Constants.PRODUCT_MWAN_SU) || ciOrder.NE__OrderId__r.Case__r.TGS_Service__c.equals(Constants.PRODUCT_MWAN_INTERNET)))
                                )
                                mapCSUID_Attr.put(attribute.Id, attribute.TGS_CSUID__c);
                        
                            if (!setOiAttributeUpdate.contains(attribute))
                                setOiAttributeUpdate.add(attribute);
                        }
                    }
                }
            } //END PCP 18/07/2016 */
            NE__OrderItem__c ciOrder = mapCiOrder.get(ciAsset.NE__AssetItemEnterpriseId__c);
            Integer lengthNameAsset = ciAsset.Name.length();
            String id_Order = ciOrder.NE__OrderId__c;
            String AssetId = ciAsset.Name.substring(lengthNameAsset-6);
            String OrderId = id_Order.substring(11,15);
            System.debug('CIORDER CSUID1 ' + ciOrder.TGS_CSUID1__c);
            System.debug('CIORDER CSUID2 ' + ciOrder.TGS_CSUID2__c);
            System.debug('CIORDER CSUID1 OLD ' + ciOrder.TGS_CSUID1_Old__c);
            System.debug('CIORDER CSUID2 OLD ' + ciOrder.TGS_CSUID2_Old__c);
            

            if(myCaseAsset.Type=='Disconnect')
            {
                System.debug('SOY TERMINATION');
                mapCSUID.put(ciOrder.Id, new List<String>{ciOrder.TGS_CSUID1__c, ciOrder.TGS_CSUID2__c, ciOrder.TGS_CSUID1_old__c, ciOrder.TGS_CSUID2_old__c});
            }
            else if(myCaseAsset.Type=='Change')
            {
                if(ciOrder.NE__Action__c!=null && ciOrder.NE__Action__c == 'Change')
                {
                    System.debug('SOY MOD-CHANGE');
                    /*ciOrder.TGS_CSUID1_Old__c = ciOrder.TGS_CSUID1__c;
                    ciOrder.TGS_CSUID2_Old__c = ciOrder.TGS_CSUID2__c;*/
                    ciOrder.TGS_CSUID1__c = AssetId+'-'+OrderId+'-'+'1';
                    ciOrder.TGS_CSUID2__c = AssetId+'-'+OrderId+'-'+'2';
                }
                else if(ciOrder.NE__Action__c!=null && ciOrder.NE__Action__c == 'Remove')
                {
                    System.debug('SOY MOD-REMOVE');
                    ciOrder.TGS_CSUID1_Old__c = ciOrder.TGS_CSUID1__c;
                    ciOrder.TGS_CSUID2_Old__c = ciOrder.TGS_CSUID2__c;
                    ciOrder.TGS_CSUID1__c = null;
                    ciOrder.TGS_CSUID2__c = null;   
                }
                else
                {
                    System.debug('SOY MOD-ADD');
                    ciOrder.TGS_CSUID1__c = AssetId+'-'+OrderId+'-'+'1';
                    ciOrder.TGS_CSUID2__c = AssetId+'-'+OrderId+'-'+'2';
                    ciOrder.TGS_CSUID1_Old__c = null;
                    ciOrder.TGS_CSUID2_Old__c = null;
                }   
                mapCSUID.put(ciOrder.Id, new List<String>{ciOrder.TGS_CSUID1__c, ciOrder.TGS_CSUID2__c, ciOrder.TGS_CSUID1_old__c, ciOrder.TGS_CSUID2_old__c});
            }
            else{
                System.debug('SOY REGISTRATION');
                ciOrder.TGS_CSUID1__c = AssetId+'-'+OrderId+'-'+'1';
                ciOrder.TGS_CSUID2__c = AssetId+'-'+OrderId+'-'+'2';
                ciOrder.TGS_CSUID1_Old__c = null;
                ciOrder.TGS_CSUID2_Old__c = null;
                mapCSUID.put(ciOrder.Id, new List<String>{ciOrder.TGS_CSUID1__c, ciOrder.TGS_CSUID2__c, ciOrder.TGS_CSUID1_old__c, ciOrder.TGS_CSUID2_old__c});
            }
            if (!setOiUpdate.contains(ciOrder)) setOiUpdate.add(ciOrder);
            System.debug('CIORDER CSUID1 ' + ciOrder.TGS_CSUID1__c);
            System.debug('CIORDER CSUID2 ' + ciOrder.TGS_CSUID2__c);
            System.debug('CIORDER CSUID1 OLD ' + ciOrder.TGS_CSUID1_Old__c);
            System.debug('CIORDER CSUID2 OLD ' + ciOrder.TGS_CSUID2_Old__c);

            if (mapCiOrderAttributes.containsKey(ciOrder.Id))
            {
                for (NE__Order_Item_Attribute__c attribute : mapCiOrderAttributes.get(ciOrder.Id)){
                    
                    if(set_BillableATTR.contains(attribute.Name))
                    {
                        String idAttribute = attribute.Id;                                
                        String attributeId = idAttribute.substring(11,15);
                        System.debug('CIATTR CSUID1 ' + ciOrder.TGS_CSUID1__c);
                        System.debug('CIATTR CSUID2 ' + ciOrder.TGS_CSUID2__c);
                        System.debug('CIATTR CSUID1 OLD ' + ciOrder.TGS_CSUID1_Old__c);
                        System.debug('CIATTR CSUID2 OLD ' + ciOrder.TGS_CSUID2_Old__c);
                        if(myCaseAsset.Type=='Disconnect')
                        {
                            /*attribute.TGS_CSUID_Old__c = attribute.TGS_CSUID__c;
                            attribute.TGS_CSUID2_Old__c = attribute.TGS_CSUID2__c;*/
                            attribute.TGS_CSUID_Old__c = map_AllATTR.get(attribute.NE__AttrEnterpriseId__c).TGS_CSUID__c;
                            attribute.TGS_CSUID2_Old__c = map_AllATTR.get(attribute.NE__AttrEnterpriseId__c).TGS_CSUID2__c;
                            attribute.TGS_CSUID__c = null;
                            attribute.TGS_CSUID2__c = null;
                            mapCSUID_Attr.put(attribute.Id, new List<String>{attribute.TGS_CSUID__c, attribute.TGS_CSUID2__c, attribute.TGS_CSUID_old__c, attribute.TGS_CSUID2_old__c});
                        }
                        else if(myCaseAsset.Type=='Change')
                        {
                            if(attribute.NE__Action__c!=null && attribute.NE__Action__c == 'Change')
                            {
                                attribute.TGS_CSUID_Old__c = attribute.TGS_CSUID__c;
                                attribute.TGS_CSUID2_Old__c = attribute.TGS_CSUID2__c;
                                attribute.TGS_CSUID__c = AssetId + '-' + OrderId + '-' + attributeId;
                                attribute.TGS_CSUID2__c = AssetId + '-' + OrderId + '-' + attributeId+'M';
                            }
                            else if(attribute.NE__Action__c!=null && attribute.NE__Action__c == 'Remove')
                            {
                                attribute.TGS_CSUID_Old__c = attribute.TGS_CSUID__c;
                                attribute.TGS_CSUID2_Old__c = attribute.TGS_CSUID2__c;
                                attribute.TGS_CSUID__c = null;
                                attribute.TGS_CSUID2__c = null;   
                            }
                            else if(attribute.NE__Action__c!=null && attribute.NE__Action__c == 'Add') 
                            {
                                attribute.TGS_CSUID__c = AssetId + '-' + OrderId + '-' + attributeId;
                                attribute.TGS_CSUID2__c = AssetId + '-' + OrderId + '-' + attributeId+'M';
                                attribute.TGS_CSUID_Old__c = null;
                                attribute.TGS_CSUID2_Old__c = null;
                            }
                            else
                            {
                                mapCSUID_Attr.put(attribute.Id, new List<String>{attribute.TGS_CSUID__c, attribute.TGS_CSUID2__c, attribute.TGS_CSUID_old__c, attribute.TGS_CSUID2_old__c});    
                            }   
                            
                        }
                        else
                        {
                            attribute.TGS_CSUID__c = AssetId + '-' + OrderId + '-' + attributeId;
                            attribute.TGS_CSUID2__c = AssetId + '-' + OrderId + '-' + attributeId+'M';
                            attribute.TGS_CSUID_Old__c = null;
                            attribute.TGS_CSUID2_Old__c = null;
                            mapCSUID_Attr.put(attribute.Id, new List<String>{attribute.TGS_CSUID__c, attribute.TGS_CSUID2__c, attribute.TGS_CSUID_old__c, attribute.TGS_CSUID2_old__c});
                        }
                        if (!setOiAttributeUpdate.contains(attribute)) setOiAttributeUpdate.add(attribute);
                    }
                }        
            }

        }
        
        System.debug(LoggingLevel.ERROR, 'mapCSUID: ' + mapCSUID);
        
        // FAR 19/05/2016
        for(NE__OrderItem__c ciAsset : listCiAsset)
        {
            if (mapCSUID.containsKey(ciAsset.NE__AssetItemEnterpriseId__c))
            {
                ciAsset.TGS_CSUID1__c = mapCSUID.get(ciAsset.NE__AssetItemEnterpriseId__c)[0];
                ciAsset.TGS_CSUID2__c = mapCSUID.get(ciAsset.NE__AssetItemEnterpriseId__c)[1];
                
                //PCP 12/07/2016 - Add csuids old to update asset ci's
                ciAsset.TGS_CSUID1_old__c = mapCSUID.get(ciAsset.NE__AssetItemEnterpriseId__c)[2];
                ciAsset.TGS_CSUID2_old__c = mapCSUID.get(ciAsset.NE__AssetItemEnterpriseId__c)[3];
                System.debug(LoggingLevel.ERROR, 'ciAsset.Name:' + ciAsset.Name);
                System.debug(LoggingLevel.ERROR, 'ciAsset.TGS_CSUID1__c:' + ciAsset.TGS_CSUID1__c);
                System.debug(LoggingLevel.ERROR, 'ciAsset.TGS_CSUID2__c:' + ciAsset.TGS_CSUID2__c);
                System.debug(LoggingLevel.ERROR, 'ciAsset.TGS_CSUID1__c:' + ciAsset.TGS_CSUID1_Old__c);
                System.debug(LoggingLevel.ERROR, 'ciAsset.TGS_CSUID2__c:' + ciAsset.TGS_CSUID2_Old__c);
                
                setOiUpdate.add(ciAsset);
                
                // FAR 02/06/2016
                if (mapCiAssetAttributes.containsKey(ciAsset.Id))
                {
                    for (NE__Order_Item_Attribute__c attr : mapCiAssetAttributes.get(ciAsset.Id))
                    {
                        if (mapCSUID_Attr.containsKey(attr.NE__AttrEnterpriseId__c))
                        {
                            /*attr.TGS_CSUID__c = mapCSUID_Attr.get(attr.NE__AttrEnterpriseId__c);
                            attr.TGS_CSUID2__c = attr.TGS_CSUID__c + 'M';*/
                            attr.TGS_CSUID__c = mapCSUID_Attr.get(attr.NE__AttrEnterpriseId__c)[0];
                            attr.TGS_CSUID2__c = mapCSUID_Attr.get(attr.NE__AttrEnterpriseId__c)[1];
                            attr.TGS_CSUID_Old__c = mapCSUID_Attr.get(attr.NE__AttrEnterpriseId__c)[2];
                            attr.TGS_CSUID2_Old__c = mapCSUID_Attr.get(attr.NE__AttrEnterpriseId__c)[3];
                            setOiAttributeUpdate.add(attr);
                        }
                    }
                }
            }
        }
        // END FAR 19/05/2016
            
        if(setOiUpdate.size()>0){
            List<NE__OrderItem__c> listOiUpdate = null;
            try{
                listOiUpdate = new List<NE__OrderItem__c>(setOiUpdate);
                update listOiUpdate;
            }catch(Exception e){
                System.debug('#### Error cuids CI: ' + e.getMessage() );
                System.debug('#### Cantidad de ci a actualizar: ' + listOiUpdate.size());
            }
        }
        if(setOiAttributeUpdate.size()>0){
            List<NE__Order_Item_Attribute__c> listOiAttributeUpdate = null;
            try{
                listOiAttributeUpdate = new List<NE__Order_Item_Attribute__c>(setOiAttributeUpdate);
                update listOiAttributeUpdate;
            }catch(Exception e){
                System.debug('#### Error cuids CI Attributes: ' + e.getMessage());
                System.debug('#### Cantidad de atributos a actualizar: ' + listOiAttributeUpdate.size());
            }
        }
    }

    /*-------------------------------------------------------------------------------------------------------------------------------------------------------
        Author:        Juan Carlos Terrón
        Company:       New Energy Aborda
        Description:   Method that fills EnterpriseId and CSUID fields on NE__OrderItem__c Records and NE__Order_Item_Attribute__c Records.
        
        IN:            Trigger.NewMap
        OUT:           Void
        
        History:   
        <Date>                  <Author>                <Change Description>
        15/09/2016          Juan Carlos Terrón                        Initial Version.        
        27/09/2016          Juan Carlos Terrón          Changed the return type to Map<String,NE__Order__c> in order to pass it as a parameter to csuid method.        
        --------------------------------------------------------------------------------------------------------------------------------------------------------*/  
        //15/09/2016 JCT Initial Version  
        public static Map<String,NE__Order__c> fill_EnterpriseID(Map<Id,Case> mapCases){
        System.debug('MS_$%& ENTRO EN FILL EID');
        Set<Id> set_OrderId = new Set<Id>();
        Set<Id> set_OrderId_mWan = new Set<Id>();
        Set<Id> set_ComercialAssetId = new Set<Id>();
        Set<Id> set_ComercialAssetId_mWan = new Set<Id>();
        Set<String> set_mSipProducts = new Set<String>{
            'mSIP Site ADMIN',
            'mSIP Site CCA',
            'mSIP Site Hosted UC',
            'mSIP Site No Trunk',
            'mSIP Site Trunk',
            'mWan',
            'mWan - Internet'
        };
        /*Map Counter = 13*/

        /*Map CaseID,NE__Order__c con RT=Asset*/
        Map<String,NE__Order__c>    map_CaseId_Asset        = new Map<String,NE__Order__c>();

        /*Order Maps*/
        Map<Id,NE__Order__c>        map_AllOrders           = new Map<Id,NE__Order__c>();
        Map<Id,NE__Order__c>        map_RTOrder             = new Map<Id,NE__Order__c>();
        Map<Id,NE__Order__c>        map_RTAsset             = new Map<Id,NE__Order__c>();

        /*Order mWan Maps*/
        Map<Id,NE__Order__c>        map_RTOrder_mWan        = new Map<Id,NE__Order__c>();
        Map<Id,NE__Order__c>        map_RTAsset_mWan        = new Map<Id,NE__Order__c>();

        /*OrderItem Maps*/
        Map<Id,NE__OrderItem__c>    map_allOrderItems       = new Map<Id,NE__OrderItem__c>();
        Map<Id,NE__OrderItem__c>    map_RTOrder_OI          = new Map<Id,NE__OrderItem__c>();
        Map<Id,NE__OrderItem__c>    map_RTAsset_OI          = new Map<Id,NE__OrderItem__c>();

        /*OrderItem mWan Maps*/
        Map<Id,NE__OrderItem__c>    map_RTOrder_OI_mWan     = new Map<Id,NE__OrderItem__c>();
        Map<Id,NE__OrderItem__c>    map_RTAsset_OI_mWan     = new Map<Id,NE__OrderItem__c>();

        /*OrderItemAttribute Maps*/
        Map<Id,NE__Order_Item_Attribute__c> map_AllAttributes = new Map<Id,NE__Order_Item_Attribute__c>();
        Map<Id,NE__Order_Item_Attribute__c> map_RTOrder_Attr  = new Map<Id,NE__Order_Item_Attribute__c>();
        Map<Id,NE__Order_Item_Attribute__c> map_RTAsset_Attr  = new Map<Id,NE__Order_Item_Attribute__c>();

        Map<Id,NE__Order_Item_Attribute__c> map_RTOrder_Attr_mWan = new Map<Id,NE__Order_Item_Attribute__c>();
        Map<Id,NE__Order_Item_Attribute__c> map_RTasset_Attr_mWan  = new Map<Id,NE__Order_Item_Attribute__c>();

        generateOrdersMap(mapCases, map_AllOrders,map_RTOrder,map_RTAsset, map_RTOrder_mWan, map_RTAsset_mWan,set_mSipProducts);
        generateComercialAssetRelation(mapCases,map_RTOrder,map_RTAsset,set_ComercialAssetId,set_OrderId, map_CaseId_Asset);
        generateComercialAssetRelation_mWan(mapCases,map_RTOrder_mWan,map_RTAsset_mWan,set_ComercialAssetId_mWan,set_OrderId_mWan,map_CaseId_Asset);

        set_OrderId.addAll(map_RTOrder.keySet());
        set_OrderId.addAll(map_RTAsset.keySet());
        set_OrderId_mWan.addAll(map_RTOrder_mWan.keySet());
        set_OrderId_mWan.addAll(map_RTAsset_mWan.keySet());

        generateOIMaps(set_OrderId,set_OrderId_mWan,map_RTOrder,map_RTAsset,map_RTOrder_mWan,map_RTAsset_mWan,map_RTOrder_OI,map_RTAsset_OI,map_RTOrder_OI_mWan,map_RTAsset_OI_mWan, map_allOrderItems);
        generateEnterpriseId(set_mSipProducts,map_allOrderItems,map_RTOrder_OI,map_RTAsset_OI,map_RTOrder_OI_mWan,map_RTAsset_OI_mWan);

        generateAttrMaps(map_RTOrder_OI, map_RTAsset_OI, map_RTOrder_Attr,map_RTAsset_Attr);
        generateAttrMaps_mWan(map_RTOrder_OI_mWan,map_RTAsset_OI_mWan,map_RTOrder_Attr_mWan,map_RTasset_Attr_mWan);
        generateAttrEnterpriseId(set_mSipProducts,map_RTOrder_Attr,map_RTAsset_Attr,map_RTOrder_Attr_mWan,map_RTAsset_Attr_mWan,map_AllAttributes);

        List<NE__Order__c> lst_Order_toUpdate = new List<NE__Order__c>();
        List<NE__OrderItem__c> lst_OI_toUpdate = new List<NE__OrderItem__c>();
        List<NE__Order_Item_Attribute__c> lst_Attr_toUpdate = new List<NE__Order_Item_Attribute__c>();

        lst_Order_toUpdate.addAll(map_RTOrder.values());lst_Order_toUpdate.addAll(map_RTAsset.values());
        lst_Order_toUpdate.addAll(map_RTOrder_mWan.values());lst_Order_toUpdate.addAll(map_RTAsset_mWan.values());

        lst_OI_toUpdate.addAll(map_RTOrder_OI.values());lst_OI_toUpdate.addAll(map_RTAsset_OI.values());
        lst_OI_toUpdate.addAll(map_RTOrder_OI_mWan.values());lst_OI_toUpdate.addAll(map_RTAsset_OI_mWan.values());

        lst_Attr_toUpdate.addAll(map_RTOrder_Attr.values());lst_Attr_toUpdate.addAll(map_RTAsset_Attr.values());
        lst_Attr_toUpdate.addAll(map_RTOrder_Attr_mWan.values());lst_Attr_toUpdate.addAll(map_RTAsset_Attr_mWan.values());

        update lst_OI_toUpdate;
        update lst_Attr_toUpdate;
        update lst_Order_toUpdate;

        return map_CaseId_Asset;
    }
    public static void generateOrdersMap(
        Map<Id,Case> mapCases,
        Map<Id, NE__Order__c> map_AllOrders,
        Map<Id,NE__Order__c> map_RTOrder,
        Map<Id,NE__Order__c> map_RTAsset,
        Map<Id,NE__Order__c> map_RTOrder_mWan,
        Map<ID,NE__Order__c> map_RTAsset_mWan,
        Set<String> set_mSipProducts
    ){
        List<NE__Order__c> lst_Orders = new List<NE__Order__c>([SELECT Id,NE__AssetEnterpriseId__c, RecordType.Name, Case__c,Case__r.Type,Case__r.TGS_Service__c,NE__Asset__c
                                FROM NE__Order__c
                                WHERE Case__c IN :mapCases.keySet()]);
        for(NE__Order__c order : lst_Orders){
            if( order.Case__r.TGS_Service__c==Constants.PRODUCT_MWAN_SU||
                order.Case__r.TGS_Service__c==Constants.PRODUCT_MWAN_INTERNET||
                set_mSipProducts.contains(order.Case__r.TGS_Service__c))
            {
                if(order.RecordType.Name==Constants.RECORD_TYPE_ORDER){
                    map_RTOrder_mWan.put(order.Id, order);
                }
                else
                {
                    map_RTAsset_mWan.put(order.Id, order);
                }   
            }
            else
            {
                if(order.RecordType.Name==Constants.RECORD_TYPE_ORDER){
                    map_RTOrder.put(order.Id, order);
                }
                else
                {
                    map_RTAsset.put(order.Id, order);
                }
            }
            map_AllOrders.put(order.Id,order);
        }
    }
    public static void generateComercialAssetRelation(
        Map<Id,Case> mapCases,
        Map<Id,NE__Order__c> map_RTOrder,
        Map<Id,NE__Order__c> map_RTAsset,
        Set<Id> set_ComercialAssetId,
        Set<Id> set_OrderId,
        Map<String,NE__Order__c> map_CaseId_Asset
    ){
        Id commAssetId;
        if(map_RTAsset.isEmpty()||map_RTAsset.size()==0||mapCases.size()!=map_RTAsset.size()){
            for(NE__Order__c order : map_RTOrder.values()){
                if(order.NE__Asset__c!=null){
                    set_ComercialAssetId.add(order.NE__Asset__c);
                }
            }
            for(NE__Order__c order : [SELECT Id, Name, NE__Asset__r.Id, NE__Asset__c, NE__AssetEnterpriseId__c, RecordType.Name, Case__c FROM NE__Order__c WHERE NE__Asset__r.Id IN :set_ComercialAssetId AND RecordType.Name = 'Asset' ]){
                map_RTAsset.put(order.Id,order);
                map_CaseId_Asset.put(String.valueOf(order.NE__Asset__c),order);
            }
        }
        else
        {
            for(NE__Order__c order : map_RTOrder.values()){
                if(order.NE__Asset__c==null){
                    commAssetId = map_RTAsset.get(mapCases.get(order.Case__c).Asset__c).NE__Asset__c;
                    order.NE__Asset__c = commAssetId;
                }
            }
        }
    }
    public static void generateComercialAssetRelation_mWan(
        Map<Id,Case> mapCases,
        Map<Id,NE__Order__c> map_RTOrder_mWan,
        Map<Id,NE__Order__c> map_RTAsset_mWan,
        Set<Id> set_ComercialAssetId_mWan,
        Set<Id> set_OrderId_mWan,
        Map<String,NE__Order__c> map_CaseId_Asset
    ){
        Id commAssetId;
        if(map_RTAsset_mWan.isEmpty()||map_RTAsset_mWan.size()==0||mapCases.size()!=map_RTAsset_mWan.size()){
            for(NE__Order__c order : map_RTOrder_mWan.values()){
                if(order.NE__Asset__c!=null){
                    set_ComercialAssetId_mWan.add(order.NE__Asset__c);
                }
            }
            for(NE__Order__c order : [SELECT Id, Name, NE__Asset__r.Id, NE__Asset__c, NE__AssetEnterpriseId__c, RecordType.Name, Case__c FROM NE__Order__c WHERE NE__Asset__r.Id IN :set_ComercialAssetId_mWan AND RecordType.Name = 'Asset' ]){
                map_RTAsset_mWan.put(order.Id,order);
                map_CaseId_Asset.put(String.valueOf(order.NE__Asset__c),order);
            }
        }
        else
        {
            for(NE__Order__c order : map_RTOrder_mWan.values()){
                if(order.NE__Asset__c==null){
                    commAssetId = map_RTAsset_mWan.get(mapCases.get(order.Case__c).Asset__c).NE__Asset__c;
                    order.NE__Asset__c = commAssetId;
                }
            }
        }
    }
    public static void generateEnterpriseId(
        Set<String> services,
        Map<Id,NE__OrderItem__c> map_allOrderItems,
        Map<Id,NE__OrderItem__c> map_RTOrder_OI,
        Map<Id,NE__OrderItem__c> map_RTAsset_OI,
        Map<Id,NE__OrderItem__c> map_RTOrder_OI_mWan,
        Map<Id,NE__OrderItem__c> map_RTAsset_OI_mWan
    ){
        Id EID;
        String ORT;
        String SERVICE;
        for(NE__OrderItem__c OI : map_allOrderItems.values()){
            EID = OI.NE__AssetItemEnterpriseId__c;
            ORT = OI.NE__OrderId__r.RecordType.Name;
            SERVICE = OI.NE__OrderId__r.Case__r.TGS_Service__c;
            System.debug('OIEID '+(EID!=OI.Id));
            if(EID!=null)
            {
                if(map_allOrderItems.containsKey(EID))
                {
                    if(ORT == 'Order')
                    {
                        if(!(map_allOrderItems.get(EID).NE__AssetItemEnterpriseId__c == OI.Id))
                        {
                            if(services.contains(SERVICE))
                            {
                                map_RTAsset_OI_mWan.get(EID).NE__AssetItemEnterpriseId__c = OI.Id;
                                map_allOrderItems.get(EID).NE__AssetItemEnterpriseId__c = OI.Id;
                            }
                            else
                            {
                                map_RTAsset_OI.get(EID).NE__AssetItemEnterpriseId__c = OI.Id;
                                map_allOrderItems.get(EID).NE__AssetItemEnterpriseId__c = OI.Id;    
                            }
                            
                        }
                    }
                    else if(map_allOrderItems.get(EID).NE__AssetItemEnterpriseId__c==null)
                    {
                        if(services.contains(SERVICE))
                        {
                            map_RTOrder_OI_mWan.get(EID).NE__AssetItemEnterpriseId__c = OI.Id;
                            map_allOrderItems.get(EID).NE__AssetItemEnterpriseId__c = OI.Id;    
                        }
                        else
                        {
                            map_RTOrder_OI.get(EID).NE__AssetItemEnterpriseId__c = OI.Id;
                            map_allOrderItems.get(EID).NE__AssetItemEnterpriseId__c = OI.Id;
                        }
                    }
                }
            }
            System.debug('OIEID '+(EID!=OI.Id));
        }
    }
    public static void generateAttrEnterpriseId(
        Set<String> services,
        Map<Id,NE__Order_Item_Attribute__c> map_RTOrder_Attr,
        Map<Id,NE__Order_Item_Attribute__c> map_RTAsset_Attr,
        Map<Id,NE__Order_Item_Attribute__c> map_RTOrder_Attr_mWan,
        Map<Id,NE__Order_Item_Attribute__c> map_RTAsset_Attr_mWan,
        Map<Id,NE__Order_Item_Attribute__c> map_AllAttributes
    ){
        Id EID;
        String ORT;
        String SERVICE;
        List<NE__Order_Item_Attribute__c> lst_AllAttributes = new List<NE__Order_Item_Attribute__c>();
        lst_AllAttributes.addAll(map_RTOrder_Attr.values());
        lst_AllAttributes.addAll(map_RTAsset_Attr.values());
        lst_AllAttributes.addAll(map_RTOrder_Attr_mWan.values());
        lst_AllAttributes.addAll(map_RTasset_Attr_mWan.values());
        map_AllAttributes = new Map<Id,NE__Order_Item_Attribute__c>(lst_AllAttributes);

        for(NE__Order_Item_Attribute__c ATTR : map_AllAttributes.values()){
            EID = ATTR.NE__AttrEnterpriseId__c;
            ORT = ATTR.NE__Order_Item__r.NE__OrderId__r.RecordType.Name;
            SERVICE = ATTR.NE__Order_Item__r.NE__OrderId__r.Case__r.TGS_Service__c;
            //System.debug('ATTREID :) ' + (EID!=ATTR.ID));
            if(EID!=null)
            {
                if(map_AllAttributes.containsKey(EID))
                {
                    if(ORT == 'Order')
                    {
                        if(!(map_AllAttributes.get(EID).NE__AttrEnterpriseId__c == ATTR.Id))
                        {
                            if(services.contains(SERVICE))
                            {
                                map_RTAsset_Attr_mWan.get(EID).NE__AttrEnterpriseId__c = ATTR.Id;
                                map_AllAttributes.get(EID).NE__AttrEnterpriseId__c = ATTR.Id;
                            }
                            else
                            {
                                map_RTAsset_Attr.get(EID).NE__AttrEnterpriseId__c = ATTR.Id;
                                map_AllAttributes.get(EID).NE__AttrEnterpriseId__c = ATTR.Id;  
                            }
                            
                        }
                    }
                    else if(map_AllAttributes.get(EID).NE__AttrEnterpriseId__c==null)
                    {
                        if(services.contains(SERVICE))
                        {
                            map_RTOrder_Attr_mWan.get(EID).NE__AttrEnterpriseId__c = ATTR.Id;
                            map_AllAttributes.get(EID).NE__AttrEnterpriseId__c = ATTR.Id;  
                        }
                        else
                        {
                            map_RTOrder_Attr.get(EID).NE__AttrEnterpriseId__c = ATTR.Id;
                            map_AllAttributes.get(EID).NE__AttrEnterpriseId__c = ATTR.Id;
                        }
                    }
                }
            }
            //System.debug('ATTREID :) ' + (EID!=ATTR.ID));
        }       
    }
    public static void generateOIMaps(
        Set<Id> set_OrderId,
        Set<Id> set_OrderId_mWan,
        Map<Id,NE__Order__c> map_RTOrder,
        Map<Id,NE__Order__c> map_RTAsset,
        Map<Id,NE__Order__c> map_RTOrder_mWan,
        Map<Id,NE__Order__c> map_RTAsset_mWan,
        Map<Id,NE__OrderItem__c> map_RTOrder_OI,
        Map<Id,NE__OrderItem__c> map_RTAsset_OI,
        Map<Id,NE__OrderItem__c> map_RTOrder_OI_mWan,
        Map<Id,NE__OrderItem__c> map_RTAsset_OI_mWan,
        Map<Id,NE__OrderItem__c> map_allOrderItems
    ){
        Map<Id,NE__OrderItem__c> mapAllOI;
        mapAllOI = new Map<Id,NE__OrderItem__c>([SELECT Id, Name,NE__AssetItemEnterpriseId__c,TGS_CSUID1__c,TGS_CSUID2__c,TGS_CSUID1_Old__c,TGS_CSUID2_Old__c,NE__Parent_Order_Item__c,
                                    Integration_Id__c,Installation_point__c,NE__Account__c,NE__Billing_Account__c,NE__Billing_Account_Asset_Item__c,NE__ProdId__r.Name,
                                    NE__Service_Account__c,NE__Service_Account_Asset_Item__c,NE__Status__c,TGS_Service_status__c,NE__ProdId__c,NE__Qty__c,NE__Action__c,
                                    TGS_billing_start_date__c,TGS_Billing_end_date__c,NE__OneTimeFeeOv__c,NE__RecurringChargeOv__c,TGS_Send_price_to_IRB__c,
                                        (SELECT Id, Name,NE__Order_Item__c,NE__FamPropId__c,NE__AttrEnterpriseId__c,NE__AttrEnterpriseIdCalc__c,
                                                TGS_CSUID__c,TGS_Key_Attribute__c,TGS_HoldingId__c,TGS_Order_Item_Name__c, NE__Order_Item__r.NE__AssetItemEnterpriseId__c,
                                                NE__Order_Item__r.NE__OrderId__r.Case__r.TGS_Service__c,NE__Order_Item__r.NE__OrderId__r.RecordType.Name
                                        FROM NE__Order_Item_Attributes__r
                                        ),
                                    NE__OrderId__r.RecordType.Name, NE__OrderId__r.Case__c, NE__OrderId__r.NE__Configuration_Type__c, NE__OrderId__r.Case__r.TGS_Service__c
                                    FROM NE__OrderItem__c
                                    WHERE NE__OrderId__c IN :set_OrderId OR NE__OrderId__c IN :set_OrderId_mWan]);
        for(NE__OrderItem__c OI : mapAllOI.values()){
            if(map_RTOrder.containsKey(OI.NE__OrderId__c))
            {
                map_RTOrder_OI.put(OI.Id,OI);
            }
            else if(map_RTAsset.containsKey(OI.NE__OrderId__c))
            {
                map_RTAsset_OI.put(OI.Id,OI);
            }
            else if(map_RTOrder_mWan.containsKey(OI.NE__OrderId__c))
            {
                map_RTOrder_OI_mWan.put(OI.Id,OI);
            }
            else
            {
                map_RTAsset_OI_mWan.put(OI.Id,OI);
            }
            map_allOrderItems.put(OI.Id, OI);
        }
    }
    /*Done*/
    public static void generateAttrMaps(Map<Id,NE__OrderItem__c> map_RTOrder,Map<Id,NE__OrderItem__c> map_RTAsset,Map<Id,NE__Order_Item_Attribute__c> map_RTOrder_Attr,Map<Id,NE__Order_Item_Attribute__c> map_RTAsset_Attr){
        List<NE__Order_Item_Attribute__c> lst_OrderAttr = new List<NE__Order_Item_Attribute__c>();
        List<NE__Order_Item_Attribute__c> lst_AssetAttr = new List<NE__Order_Item_Attribute__c>();
        for(NE__OrderItem__c OI : map_RTOrder.values()){
            lst_OrderAttr.addAll(OI.NE__Order_Item_Attributes__r);
        }
        for(NE__OrderItem__c OI : map_RTasset.values()){
            lst_AssetAttr.addAll(OI.NE__Order_Item_Attributes__r);
        }
        for(NE__Order_Item_Attribute__c attr : lst_OrderAttr){
            map_RTOrder_Attr.put(attr.Id,attr);
        }
        for(NE__Order_Item_Attribute__c attr : lst_AssetAttr){
            map_RTAsset_Attr.put(attr.Id,attr);
        }
        
    }
    /*Done*/
    public static void generateAttrMaps_mWan(Map<Id,NE__OrderItem__c> map_RTOrder_mWan,Map<Id,NE__OrderItem__c> map_RTAsset_mWan,Map<Id,NE__Order_Item_Attribute__c> map_RTOrder_Attr_mWan,Map<Id,NE__Order_Item_Attribute__c> map_RTasset_Attr_mWan){
        List<NE__Order_Item_Attribute__c> lst_OrderAttr = new List<NE__Order_Item_Attribute__c>();
        List<NE__Order_Item_Attribute__c> lst_AssetAttr = new List<NE__Order_Item_Attribute__c>();
        for(NE__OrderItem__c OI : map_RTOrder_mWan.values()){
            lst_OrderAttr.addAll(OI.NE__Order_Item_Attributes__r);
        }
        for(NE__OrderItem__c OI : map_RTAsset_mWan.values()){
            lst_AssetAttr.addAll(OI.NE__Order_Item_Attributes__r);
        }
        for(NE__Order_Item_Attribute__c attr : lst_OrderAttr){
            map_RTOrder_Attr_mWan.put(attr.Id,attr);
        }
        for(NE__Order_Item_Attribute__c attr : lst_AssetAttr){
            map_RTAsset_Attr_mWan.put(attr.Id,attr);
        }
        
    }
    //15/09/2016  JCT END JCT 15/09/2016
}