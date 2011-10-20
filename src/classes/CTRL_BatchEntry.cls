/*
Copyright (c) 2011, salesforce.com foundation, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, 
    this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, 
    this list of conditions and the following disclaimer in the documentation 
    and/or other materials provided with the distribution.
    * Neither the name of the salesforce.com foundation. nor the names of its contributors 
    may be used to endorse or promote products derived from this software 
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
OF THE POSSIBILITY OF SUCH DAMAGE.

*/
/**
* @author Team Kick Ass; Veronica Waters, Evan Callahan, Derek Dsouza, Mike Fullmore
* @date 04/27/2011
* @description controller for the batch entry page.
*/

public with sharing class CTRL_BatchEntry {

        public batch__c batch { get; set; }
        public boolean displayBatchSection { get; private set; }   // could be transient?
        public boolean displayRecInfoSection { get; private set; }     // could be transient?
        public boolean displaySettingsSection { get; private set; }     // could be transient?
        
        public List<SelectOption> objectSettingsList { get; private set; }
        
        public BatchItem currentItem { get; set; }   // could be transient - already getting it on edit, otherwise should be clear (what about errors?)
        public list<BatchItem> itemList { get; private set; }	// could be transient - would need list of ids instead

		// could get all this every time, but not a lot of viewstate
        public string objname { get; set; }
        public string batchLookupField { get; private set; }
        public string pageSubtitle { get; private set; }
        public list<EntryField> entryFieldList { get; private set; }
        public list<string> listFieldList { get; private set; }
        
        public Batch_Data_Entry_Config__c bdec {get; set;}
        
        public integer itemCount { get { return (itemList != null) ? itemList.size() : 0; } }
                
        map<id, OpportunityContactRole> ocrlookup;
        
        public CTRL_BatchEntry(ApexPages.StandardController stdController) {

                if (stdController.getId() == null)
                	batch = new Batch__c();
                else
                	batch = [select id, name, object_name__c, batch_status__c, Number_of_Items__c from batch__c where id =: stdController.getId()];

                objname = (batch.id != null) ? 
                        batch.object_name__c :
                        ApexPages.currentPage().getParameters().get('obj');        
        }
        
        public void initializeBatchEntry(){
        	   
            bdec = Batch_Data_Entry_Config__c.getOrgDefaults();
            
            //no defaults yet loaded, create one
            if (bdec == null){
                bdec = new Batch_Data_Entry_Config__c();
                insert bdec;
            }     
        	
            BulkDataEntry bde = new BulkDataEntry(objname);                
                
            if (!bde.getStatusMessage().contains(bde.getFailureMessage())){             
                objname = bde.getObjectName();
                    
                if(objname!=null) {
                    batchLookupField = bde.getBatchLookupFieldname();
                    displayBatchSection = bde.getSaveBatch();                       
                    displayRecInfoSection = true;
                            
                    String pluralName = DescribeHelper.getObjectDescribe(objname).getLabelPlural();
                    pageSubtitle = pluralName;
                                                    
                    entryFieldList = new list<EntryField>();
                    
                    for (string fn : bde.getEntryFieldList())
                        entryFieldList.add(new EntryField(objname, fn));
                    
                    listFieldList = bde.getListFieldList();                   
                    itemList = new list<BatchItem>();
                    
                    if (displayBatchSection) {
                        // create the batch if it is new
                        if (batch.id == null) {                                        
                            batch.name = pluralName + ' ' + system.today().format();
                            batch.object_name__c = objName;
                            // we will insert this in the load event
                        } 
                        else {
                            string q = bde.getQueryString();
                            q += ' where ' + batchLookupField + ' = \'' + batch.id + '\'';
                          
                            list<sobject> existingsobjs = database.query(q);
                            
                            //if its opps and npsp, query for the ocrs
                            //so we can properly backfill the objects in the batch items
                            if (existingsobjs[0].getSobjectType() == Opportunity.Sobjecttype && bdec.Has_NPSP__c == true){
                                list<OpportunityContactRole> ocrlist = [select id, OpportunityID, ContactID from OpportunityContactRole where OpportunityID IN :existingsobjs and isPrimary = true];
                                for (OpportunityContactRole ocr : ocrlist){
                                	ocrlookup.put(ocr.OpportunityID, ocr);
                                }                                                           	   
                            }
                          
                            for (sObject existing : existingsobjs) {
                                itemList.add(new BatchItem(this, existing));
                            }       
                        }
                    }
                    
                    currentItem = new BatchItem(this);
                } 
                else{
                    objectSettingsList = new List<SelectOption>();
                    
                    for(BulkDataEntry__c b : bde.getBulkCustomSettingsList()) {
                        objectSettingsList.add(new SelectOption(b.Name, DescribeHelper.getObjectDescribe(b.Name).getLabel()));
                    }
                    
                    pageSubtitle = 'Batch Data Entry Home';
                    displaySettingsSection = true;
                    displayBatchSection = false;
                    displayRecInfoSection = false;                          
                }                       
            } 
            else{             
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, bde.getStatusMessage()));
                displaySettingsSection = false;
                displayBatchSection = false;
                displayRecInfoSection = false;
            }                
        }

      	public class EntryField {
        	    public string fieldName { get; private set; }
            	public string fieldLabel { get; private set; }
                        
            	public entryField(string obj, string fld) {
                	fieldName = fld;
                    fieldLabel = DescribeHelper.getFieldLabel(obj, fld);
                    if(fieldName.toUpperCase().endsWith('ID') && fieldLabel.toUpperCase().endsWith('ID'))     
                    	fieldLabel=fieldLabel.substring(0, fieldLabel.length()-2);               
                }
        }
                
        public class BatchItem {
                
                CTRL_BatchEntry mydad;
                public integer itemNum { get; private set; }
                public sobject sobj { get; set; }
                public boolean renderNPSPContact{get; set;} 
                
                //empty object for using the 
                //ocr ContactID lookup field for NPSP donations
                public OpportunityContactRole npspocr {get; set;}
                                
                public BatchItem(CTRL_BatchEntry parentClass) {
                        mydad = parentClass;       
                        sobj = DescribeHelper.getPrototypeObject(mydad.objname); //this line needs to be outside the check for displayBatchSection or we get an error on page load for any object where !displayBatchSection          
                        renderNPSPContact = false;
                        if (mydad.displayBatchSection) {
                            sobj.put(mydad.batchLookupField, parentClass.batch.id);
                        }
                        
                        //generate a 'dummy' ocr for npsp donation entry
                        if (mydad.objname == 'Opportunity' && mydad.bdec.Has_NPSP__c == true){
                        	npspocr = new OpportunityContactRole();
                        	renderNPSPContact = true;
                        }                        
                }
                
                public BatchItem(CTRL_BatchEntry parentClass, sobject existingItem) {
                    mydad = parentClass;
                    sobj = existingItem;
                    renderNPSPContact = false;
                    //get the actual primary ocr for this npsp opp
                    if(sobj.getSObjectType() == Opportunity.Sobjecttype && mydad.bdec.Has_NPSP__c == true){
                        npspocr = mydad.ocrlookup.get(sobj.id);
                        renderNPSPContact = true;
                    }                                                
                }
                
                public pageReference editItem() {
                    // load this item into data entry section
                    myDad.currentItem = this;
                    return null;
                }
                
                public pageReference deleteItem() {
                    // delete this item from the list
                    myDad.deleteItem(sobj);
                    return null;
                                    
                }
                
                public pageReference viewItem(){
                	ApexPages.Pagereference pr = new ApexPages.Pagereference('/' + sobj.id);
                	return pr;
                }
                
                //automatic donation naming	
                public string createName(){
                    string namestring = '';
                    
                    //if we have an NPSP Contact, start there, else, use the account name
                    if (myDad.bdec.Has_NPSP__c && npspocr.ContactID != null){
                        namestring += [select Name from Contact where id = :npspocr.ContactID].Name;
                    }
                    else{
                    	id accid = (id)sobj.get('AccountID');
                    	namestring += [select Name from Account where id = :accid].Name;
                    }
                    
                    date oppdate = (date)sobj.get('CloseDate');
                    namestring += ' ' + oppdate.format();
                    
                    if (sobj.get('RecordTypeID') != null){
                    	id recid = (id)sobj.get('RecordTypeID');
                    	namestring += ' ' + [select Name from RecordType where id = :recid].Name;
                    }
                                                        	
                	return namestring; 
                }
                
                
        }
        
        public pageReference saveBatch() {
				// if we are using batch, save the batch                
                if (displayBatchSection && itemList!=null && !itemList.isEmpty()) {
                	batch.number_of_items__c = itemList.size();

                	if (batch.id == null)
                        insert batch;
                    else
                    	update batch;
                }
                return null;
        }
        
        public pageReference save() {
        		if (currentItem.sobj.id != null) {
        			if(currentItem.sobj.getSObjectType() == Opportunity.Sobjecttype && bdec.Has_NPSP__c == true){
                            currentItem.sobj.put('npe01__Contact_ID_for_Role__c', currentItem.npspocr.ContactID);
        			}
                    
                    update currentItem.sobj;
                } else {         
                		if(currentItem.sobj.getSObjectType() == Opportunity.Sobjecttype && bdec.Has_NPSP__c == true){
                            currentItem.sobj.put('npe01__Contact_ID_for_Role__c', currentItem.npspocr.ContactID);
                        }
                      
                        //use automatic opp naming 
                		if(currentItem.sobj.getSObjectType() == Opportunity.Sobjecttype && bdec.Opportunity_Naming__c == true){
                            currentItem.sobj.put('Name', currentItem.createName());
                		}
                		
                		if (itemList.isEmpty()) {
                				itemList.add(currentItem);
                        		saveBatch();
                        		//we can't guarantee a lookup field when running tests
                        		//so skip this line when in a test context
                        		if (!test.isRunningTest())
                                    currentItem.sobj.put(batchLookupField, batch.Id);
                        		
                        		insert currentItem.sobj;                                
                        }
                        else {
                        		insert currentItem.sobj;
                                itemList.add(0, currentItem);
                        }                        
                }
                currentItem = new BatchItem(this);
                return null;    
        }

        public pageReference clear() {
                currentItem = new BatchItem(this);
                return null;
        }
        
        public void deleteItem(sobject sobj) {
                delete sobj;
                for (integer i = 0; i < itemList.size(); i++) {
                        if (itemList[i].sobj.id == sobj.id) { 
                                itemList.remove(i);
                                break;
                        }
                }
        }
        
        public pageReference openBatchEnterPage() {
        	PageReference pageRef = Page.BatchEntry;
        	pageRef.getParameters().put('obj', objName);
        	pageRef.setRedirect(true);
        	return pageRef;        	
        }
        
        public pageReference editBatchSetting() {
        	//List<BulkDataEntry__c> setting = [Select Id from BulkDataEntry__c where Name=:objName];        	
        	//PageReference pageRef = new PageReference('/' + setting[0].Id);
        	List<BulkDataEntry__c> setting = [Select Id from BulkDataEntry__c where Name=:objName];
        	PageReference pageRef = new PageReference('/apex/BatchEntrySettings?' + 'setting=' + setting[0].id );
        	return pageRef;   	
        }
        
        public pageReference createBatchSetting() {
        	//String id = DescribeHelper.getObjectDescribe(String.valueOf(BulkDataEntry__c.sObjectType)).getKeyPrefix();        	
        	//PageReference pageRef = new PageReference('/setup/ui/editCustomSettingsData.apexp');
        	PageReference pageRef = new PageReference('/apex/BatchEntrySettings');
        	//pageRef.getParameters().put('id', id);
        	//pageRef.getParameters().put('retURL', Page.BatchEntry.getUrl());
        	return pageRef;   	
        }
        
        /* Tests */
        
	    static testMethod void testBatchWithSave() {
			// create settings object			
			BulkDataEntry__c contact_bde = BulkDataEntry__c.getInstance('Contact');
			if (contact_bde == null){
                BulkDataEntry__c bde = new BulkDataEntry__c(Name = 'Contact');
                insert bde;
			}
			
			ApexPages.StandardController sc = new ApexPages.standardController( new Batch__c() );
			Test.setCurrentPage(Page.BatchEntry); 
			ApexPages.currentPage().getParameters().put('obj', 'Contact');
			CTRL_BatchEntry ext = new CTRL_BatchEntry(sc); 
            
            system.assertNotEquals(null, ext.currentItem);
			
			// set some fields
			ext.currentItem.sobj.put('LastName', 'Test');
			ext.save();		
	
			// do it again with the saved record
			sc = new ApexPages.standardController( ext.batch );
			Test.setCurrentPage(Page.BatchEntry); 
			ApexPages.currentPage().getParameters().put('obj', 'Contact');
			ext = new CTRL_BatchEntry(sc); 
		}
	
		static testMethod void testBatchNotSaved() {
			
		}        
}