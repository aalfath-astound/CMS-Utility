/**
 * @description this batch class fetches the public images from URLs and then store them in CMS
 * @author            : a.alfath@astounddigital.com
 * @group             : 
 * @last modified on  : 04-16-2026
 * @last modified by  : a.alfath@astounddigital.com
**/


public with sharing class B2B_PublicImageToCMSBatchFromURL implements Database.Batchable<SObject>, Database.AllowsCallouts {
  private String publicImageFieldApiName;
  private String cmsImageFieldApiName;
  private String query;
  private String managedContentSpaceId;
  private List<String> productSkuList;

  @TestVisible
  private B2B_ConnectApiProvider.ConnectApiInterface connectApiProvider = new B2B_ConnectApiProvider();

  
  /**
  * @description : parameterized constructor to take the required parameters including the list of product skus to process, if the list is null it will process all the products with image urls which are not processed yet
  * @author a.alfath@astounddigital.com | 04-16-2026 
  * @param managedContentSpaceId 
  * @param productSkus 
  **/
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public B2B_PublicImageToCMSBatchFromURL(
    String managedContentSpaceId,
    List<String> productSkus
      
  ) {
    this.productSkuList = productSkus;
    this.managedContentSpaceId = managedContentSpaceId;
  }
    
  /**
  * @description : parameterized constructor to take the required parameters without product skus list, it will fetch all the products with image urls which are not processed yet
  * @author a.alfath@astounddigital.com | 04-16-2026 
  * @param managedContentSpaceId 
  **/
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public B2B_PublicImageToCMSBatchFromURL(
    String managedContentSpaceId
      
  ) {
    this.managedContentSpaceId = managedContentSpaceId;
  }
    

  /**
   * @description start method for the batch job
   * @param bContext - the context for the batchable job
   * @return Database.QueryLocator - the query locator for the batch job
   */
  public Database.QueryLocator start(Database.BatchableContext bContext) {
      
      
      if(this.productSkuList == null){
          query = 'select id, StockKeepingUnit, product_image_Url__c from product2 where isProcessed__c = false and product_image_Url__c!=null';
      }
      if(this.productSkuList != null){
          query = 'select id, StockKeepingUnit ,product_image_Url__c from product2 where StockKeepingUnit in:productSkuList and product_image_Url__c!=null';
      }
    return Database.getQueryLocator(query);
  }

  /**
   * @description execute method for processing each batch of records
   * @param bContext - the context for the batchable job
   * @param scope - the list of SObjects to process in this batch
   * @throws System.CalloutException - if a callout is made outside of the allowed
   * @throws ConnectApi.ConnectApiException - if there is an error with the Connect API
   */
  public void execute(Database.BatchableContext bContext, List<SObject> scope) {
    if (scope.isEmpty()) {
      return;
    }

    Map<String, String> contentKeysByRecordId = new Map<String, String>();
    Map<String, String> contentKeysBycontentId = new Map<String, String>();
    Map<String,string> productIdToProductSku = new Map<String,string>();
    Map<String,string> ProductSkuToProductId = new Map<String,string>();
    Map<String,string> ProductSkuToProductUrl = new Map<String,string>();
    List<ProductMedia> productsMedias = new List<ProductMedia>();
    List<string> contentKeys = new List<string>();
    List<Product2> productsToUpdate = new List<Product2>();
      
      for (SObject record : scope) {
          product2 p = (product2) record; 
          productIdToProductSku.put(record.id, (String)p.StockKeepingUnit);
          ProductSkuToProductId.put(p.StockKeepingUnit, record.id);
          ProductSkuToProductUrl.put(p.StockKeepingUnit,p.product_image_Url__c);
      }
      Map<String, Blob> productSkuToImageBlob = new Map<String, Blob>();
      
      productSkuToImageBlob = B2B_FileUrlUtil.fetchImageAndSaveAsFile(ProductSkuToProductUrl);
      
// Mapping the product Id to the content key after publishing to CMS
    for (SObject record : scope) {
        product2 p = (product2) record; 
        system.debug('product p'+p);
        Blob imageBlob = productSkuToImageBlob.get((string)p.StockKeepingUnit);
        String mimeType = 'image/png'; //finalResponse.getHeader('Content-Type');
        contentKeysByRecordId.put(
          (String) record.get('Id'),
          publishImageToCMS(
            imageBlob,
            mimeType,
            (String) p.StockKeepingUnit
          )
        );
      }
      
      contentKeys.addAll(contentKeysByRecordId.values());

    if (!contentKeysByRecordId.isEmpty()) {
      // bring all the content ids from content keys
      List<String> contentIdsToPublish = new List<String>();
      for (
        ManagedContent record : connectApiProvider.getManagedContentsByKeys(
          new Set<String>(contentKeysByRecordId.values())
        )
      ) {
        contentIdsToPublish.add(record.Id);
      }

      // finally publish the content
      ConnectApi.ManagedContentPublishInput publishInput = new ConnectApi.ManagedContentPublishInput();
      publishInput.contentIds = contentIdsToPublish;
      // ConnectApi.ManagedContentPublishOutput publishResult =
      connectApiProvider.publish(publishInput);
      // System.debug('Publish Result: ' + publishResult);
      
      ElectronicMediaGroup pDpGroup = [SELECT Id FROM ElectronicMediaGroup 
                                 WHERE DeveloperName = 'ProductDetailImage' 
                                 LIMIT 1];
        
      ElectronicMediaGroup pLPGroup = [SELECT Id FROM ElectronicMediaGroup 
                                 WHERE DeveloperName = 'productListImage' 
                                 LIMIT 1];
     
       // Fetch the ManagedContent records again to get their IDs for linking to ProductMedia records 
       List<ManagedContent> managedContentRecords = [SELECT ContentKey, Id, Name FROM ManagedContent where contentKey in:contentKeysByRecordId.values()];
       
        for(ManagedContent cm: managedContentRecords){
            contentKeysBycontentId.put(cm.ContentKey,cm.id);
        }
 
        for( string productId:contentKeysByRecordId.keySet()){
            
            ProductMedia pMedia = new ProductMedia();
            pMedia.ProductId = productId;
            pMedia.ElectronicMediaId = contentKeysBycontentId.get(contentKeysByRecordId.get(productId)); // /*'20Ya5000008qGP3EAM'; */ Link to CMS Content
            pMedia.SortOrder = 1; // Position in the PDP gallery (lower numbers show first)
            pMedia.ElectronicMediaGroupId = pDpGroup.Id;
            
            productsMedias.add(pMedia);
            
            ProductMedia pMedia1 = new ProductMedia();
            pMedia1.ProductId = productId;
            pMedia1.ElectronicMediaId = contentKeysBycontentId.get(contentKeysByRecordId.get(productId)); // /*'20Ya5000008qGP3EAM'; */ Link to CMS Content
            pMedia1.SortOrder = 1; // Position in the PDP gallery (lower numbers show first)
            pMedia1.ElectronicMediaGroupId = pLpGroup.Id;
            
            productsMedias.add(pMedia1);
            
            Product2 p = new product2(id = productId, isProcessed__c = true);
            productsToUpdate.add(p);
        }
        
        if(productsMedias.size()>0){
            insert productsMedias;
        }
        
        if(productsToUpdate.size()>0){
            update productsToUpdate;
        }

    }
  }

  /**
   * @description finish method of the batch which is invoked when the batch job is completed
   * @param bContext - the context for the batchable job
   */
  public void finish(Database.BatchableContext bContext) {
    // Any final processing can be done here
    bContext.getJobId();
  }

  /**
   * @description helper method to publish the image to CMS
   * @param imageBlob - the Blob containing the image data
   * @param mimeType - the MIME type of the image
   * @param title - the title for the image
   * @return String - the content key of the published image
   * @throws ConnectApi.ConnectApiException - if there is an error with the Connect API
   */
  private String publishImageToCMS(
    Blob imageBlob,
    String mimeType,
    String title
  ) {
    String fileName = title + '.' + mimeType.split('/')[1]; // e.g., 'image/jpeg' -> 'jpeg'
      System.debug('imageBlob::'+imageBlob);
      System.debug('mimeType::'+mimeType);
      System.debug('title::'+title);
      System.debug('fileName::'+fileName);
    ConnectApi.BinaryInput contentData = new ConnectApi.BinaryInput(
      imageBlob,
      mimeType,
      fileName
    );

    ConnectApi.ManagedContentDocumentInput managedContentInput = new ConnectApi.ManagedContentDocumentInput();
    managedContentInput.title = title;
    managedContentInput.contentBody = new ConnectApi.ManagedContentBodyInput();
    managedContentInput.contentBody.nodeMap = new Map<String, Object>{
      'sfdc_cms:media' => new Map<String, Object>{
        'source' => new Map<String, String>{
          'type' => 'file',
          'mimeType' => mimeType
        }
      }
    };
        
    managedContentInput.contentType = 'sfdc_cms__image';
    managedContentInput.contentSpaceOrFolderId = this.managedContentSpaceId;

    ConnectApi.ManagedContentDocument resultContent = connectApiProvider.createManagedContentWithMedia(
      managedContentInput,
      contentData
    );

    // System.debug(resultContent);

    // return the content key to publish later
    return resultContent.contentKey;
  }
}