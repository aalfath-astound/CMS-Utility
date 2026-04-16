/**
 * @description       : Batch class to fetch public images from Library or static resource and store them in CMS
 * @author            : a.alfath@astounddigital.com
 * @group             : 
 * @last modified on  : 04-16-2026
 * @last modified by  : a.alfath@astounddigital.com
**/

 public with sharing class B2B_PublicImageToCMSBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
  private String publicImageFieldApiName;
  private String cmsImageFieldApiName;
  private String query;
  private String managedContentSpaceId;
  private String titleFieldApiName;
  private String productSku;
  private List<String> productSkuList;
  private String field;
  private boolean isStaticResource;
  private String staticResourceOrLibraryName;



  @TestVisible
  private B2B_ConnectApiProvider.ConnectApiInterface connectApiProvider = new B2B_ConnectApiProvider();

  /**
   * @description parameterized constructor to take the required parameters
   * @param managedContentSpaceId - the ID of the managed content space or folder where the images will be stored
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public B2B_PublicImageToCMSBatch(
    String query,
    String managedContentSpaceId,
    String productSku,
    String field
  ) {
    this.query = query;
    this.isStaticResource = false;
    this.productSku = productSku;
    this.managedContentSpaceId = managedContentSpaceId;
    this.field = field;
  }
    
  /**
  * @description : parameterized constructor to take the required parameters with option to specify if the images are stored in static resource or library and the name of the static resource if applicable
  * @author a.alfath@astounddigital.com | 04-16-2026 
  * @param query 
  * @param managedContentSpaceId 
  * @param productSku 
  * @param field 
  * @param staticResourceOrLibraryName 
  * @param isStaticResource 
  **/
    @SuppressWarnings('PMD.ExcessiveParameterList')
  public B2B_PublicImageToCMSBatch(
    String query,
    String managedContentSpaceId,
    String productSku,
    String field,
    String staticResourceOrLibraryName,
    Boolean isStaticResource
  ) {
    this.query = query;
    this.isStaticResource = isStaticResource;
    this.staticResourceOrLibraryName = staticResourceOrLibraryName;
    this.productSku = productSku;
    this.managedContentSpaceId = managedContentSpaceId;
    this.field = field;
  }

  /**
   * @description start method for the batch job
   * @param bContext - the context for the batchable job
   * @return Database.QueryLocator - the query locator for the batch job
   */
  public Database.QueryLocator start(Database.BatchableContext bContext) {
      
      if(this.field == null){
         this.field = 'StockKeepingUnit' ;
      }
      if(this.productSku == null && this.query == null){
          query = 'select id, '+this.field+' from product2 where isProcessed__c = false';
      }
      if(this.productSku != null){
          query = 'select id, '+this.field+' from product2 where '+this.field+' =:productSku';
      }
    return Database.getQueryLocator(query);
  }

  
  /**
  * @description : execute method for the batch job which processes each batch of records. It retrieves the image blobs for the products in the current batch, publishes them to CMS, and updates the ProductMedia and Product2 records accordingly.
  * @author a.alfath@astounddigital.com | 04-16-2026 
  * @param bContext 
  * @param scope 
  **/
  public void execute(Database.BatchableContext bContext, List<SObject> scope) {
    if (scope.isEmpty()) {
      return;
    }

    Map<String, String> contentKeysByRecordId = new Map<String, String>();
    Map<String, String> contentKeysBycontentId = new Map<String, String>();
    Map<String,string> productIdToProductSku = new Map<String,string>();
    Map<String,string> ProductSkuToProductId = new Map<String,string>();
    List<ProductMedia> productsMedias = new List<ProductMedia>();
    List<string> contentKeys = new List<string>();
    List<Product2> productsToUpdate = new List<Product2>();
      
      for (SObject record : scope) {
          product2 p = (product2) record; 
          productIdToProductSku.put(record.id, (String)p.get(this.field));
          ProductSkuToProductId.put((String)p.get(this.field), record.id);
      }
      Map<String, Blob> productSkuToImageBlob = new Map<String, Blob>();

      // Fetch image blobs from either static resource or library based on the isStaticResource flag
      if(isStaticResource && staticResourceOrLibraryName!=null){
          productSkuToImageBlob = B2B_FileUrlUtil.getImageBlobsFromStaticResource(staticResourceOrLibraryName,new Set<String>(productIdToProductSku.values()));
      }
       else{
          productSkuToImageBlob = B2B_FileUrlUtil.getImageBlobsFromLibrary(staticResourceOrLibraryName,new Set<String>(productIdToProductSku.values()));
      }
 // Mapping the product Id to the content key after publishing to CMS
   for (SObject record : scope) {
        product2 p = (product2) record; 
        Blob imageBlob = productSkuToImageBlob.get((string)p.get(this.field));
        String mimeType = 'image/png'; //finalResponse.getHeader('Content-Type');
        contentKeysByRecordId.put(
          (String) record.get('Id'),
          publishImageToCMS(
            imageBlob,
            mimeType,
            (String) p.get(this.field)
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
      connectApiProvider.publish(publishInput);
      
      // Map the published content keys to the product Ids for updating ProductMedia records
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

    return resultContent.contentKey;
  }
}