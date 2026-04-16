/**
 * @description       : Utility class for handling file URLs and blobs in the B2B context
 * @author            : a.alfath@astounddigital.com
 * @group             : 
 * @last modified on  : 04-16-2026
 * @last modified by  : a.alfath@astounddigital.com
**/
public class B2B_FileUrlUtil {

    
    /**
    * @description : Fetches image URLs from a specified Salesforce library based on product names. It queries the library for documents, filters them by the provided product names and supported image file types, and returns a map of product names to their corresponding download URLs.
    * @author a.alfath@astounddigital.com | 04-16-2026 
    * @param libraryName 
    * @param productsNames 
    * @return Map<String, String> 
    **/
    public static Map<String, String> getImageUrlsFromLibrary(String libraryName, Set<String> productsNames) {
        
        // Get the library
        ContentWorkspace library = [
            SELECT Id FROM ContentWorkspace
            WHERE Name = :libraryName
            LIMIT 1
        ];

        // ContentWorkspaceDoc links DOCUMENTS to a library
        List<ContentWorkspaceDoc> wsDocs = [
            SELECT ContentDocumentId
            FROM ContentWorkspaceDoc
            WHERE ContentWorkspaceId = :library.Id
        ];

        Set<Id> docIds = new Set<Id>();
        for (ContentWorkspaceDoc d : wsDocs) {
            docIds.add(d.ContentDocumentId);
        }

        // Get latest image versions
        List<ContentVersion> versions = [
            SELECT Id, Title, FileType, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND Title IN :productsNames 
            AND FileType IN ('PNG', 'JPG', 'JPEG', 'GIF', 'SVG', 'WEBP')
            AND IsLatest = true
        ];

        // Build Title => Download URL map
        Map<String, String> urlMap = new Map<String, String>();
        for (ContentVersion cv : versions) {
            urlMap.put(cv.Title, '/sfc/servlet.shepherd/version/download/' + cv.Id);
        }

        return urlMap;
    }
    
    /**
    * @description : Similar to getImageUrlsFromLibrary, but instead of returning URLs, it retrieves the actual image blobs for the specified product names from the library. It queries the same set of documents and versions, but instead of constructing URLs, it builds a map of product names to their corresponding image blobs.
    * @author a.alfath@astounddigital.com | 04-16-2026 
    * @param libraryName 
    * @param productsNames 
    * @return Map<String, Blob> 
    **/
    public static Map<String, Blob> getImageBlobsFromLibrary(String libraryName,Set<String> productsNames) {

        ContentWorkspace library = [
            SELECT Id FROM ContentWorkspace
            WHERE Name = :libraryName
            LIMIT 1
        ];

        List<ContentWorkspaceDoc> wsDocs = [
            SELECT ContentDocumentId
            FROM ContentWorkspaceDoc
            WHERE ContentWorkspaceId = :library.Id
        ];

        Set<Id> docIds = new Set<Id>();
        for (ContentWorkspaceDoc d : wsDocs) {
            docIds.add(d.ContentDocumentId);
        }

        List<ContentVersion> versions = [
            SELECT Id, Title, FileType, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND Title IN :productsNames 
            AND FileType IN ('PNG', 'JPG', 'JPEG', 'GIF', 'SVG', 'WEBP')
            AND IsLatest = true
        ];

        Map<String, Blob> blobMap = new Map<String, Blob>();
        for (ContentVersion cv : versions) {
            blobMap.put(cv.Title, cv.VersionData);
        }

        return blobMap;
    }
    
    
    /**
    * @description : Fetches image blobs from a specified static resource ZIP file based on product names. It constructs potential file paths for each product name with common image extensions, attempts to retrieve the content as a blob, and builds a map of product names to their corresponding image blobs if found.
    * @author a.alfath@astounddigital.com | 04-16-2026 
    * @param resourceName 
    * @param productsNames 
    * @return Map<String, Blob> 
    **/
    public static Map<String, Blob> getImageBlobsFromStaticResource(String resourceName,Set<String> productsNames) {
        Map<String, Blob> contentBlobmap = new Map<String, Blob>();
        
        Blob imageBlob;
        List<String> extensions = new List<String>{'.png', '.jpeg', '.jpg'};
            
            for(String ext : extensions) {
                for(String prodName : productsNames){
                    try {
                        // Construct the URL path to the file inside the ZIP
                        // Format: /resource/Timestamp/ResourceName/path/to/file.ext
                        PageReference pr = new PageReference('/resource/' + resourceName + '/' + prodName + ext);
                        
                        // This attempts to fetch the specific file from the ZIP
                        imageBlob = pr.getContent(); 
                        
                        if(imageBlob != null) {
                            contentBlobmap.put(prodName,imageBlob);
                            System.debug('Found image with extension: ' + ext);
                            break; // Exit loop once found
                        }
                        
                    } catch (Exception e) {
                        // If the extension doesn't exist, it throws an error; move to the next
                        continue;
                    }
                }
            }
        return contentBlobmap;
    }
    
    /**
    * @description : Fetches images from given URLs and saves them as blobs in a map. It iterates through the provided map of product names to image URLs, makes HTTP GET requests to each URL, retrieves the image content as blobs, and builds a new map of product names to their corresponding image blobs. If any URL fails to fetch, it simply continues to the next one without throwing an error.
    * @author a.alfath@astounddigital.com | 04-16-2026 
    * @param productsNameToImageURL 
    * @return Map<String, Blob> 
    **/
    public static Map<String, Blob> fetchImageAndSaveAsFile(Map<String,String> productsNameToImageURL) {
        Map<String, Blob> prodNameToBlob = new Map<String, Blob>();
        for(String prodName:productsNameToImageURL.keySet()){
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(productsNameToImageURL.get(prodName));
                req.setMethod('GET');
                req.setTimeout(10000);
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 200) {
                    Blob imageBlob = res.getBodyAsBlob();
                    prodNameToBlob.put(prodName,imageBlob);
                    
                }
            } catch (Exception e) {
                // If the extension doesn't exist, it throws an error; move to the next
                continue;
            }
        }
        
        return prodNameToBlob;
    }
    
    /**
    * @description : Fetches an image from a given URL and saves it as a Salesforce File (ContentVersion). It makes an HTTP GET request to the specified image URL, retrieves the image as a blob, and then creates a new ContentVersion record with the provided file name. Finally, it returns the ContentDocumentId of the newly created file for reference.
    * @author a.alfath@astounddigital.com | 04-16-2026 
    * @param imageUrl 
    * @param fileName 
    * @return String 
    **/
    @AuraEnabled
    public static String fetchImageAndSaveAsFile(String imageUrl, String fileName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(imageUrl);
        req.setMethod('GET');
        req.setTimeout(10000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Blob imageBlob = res.getBodyAsBlob();

            // Save as Salesforce File (ContentVersion)
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.jpg';
            cv.VersionData = imageBlob;
            cv.IsMajorVersion = true;
            insert cv;

            // Get the ContentDocumentId
            ContentVersion inserted = [
                SELECT Id, ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id
            ];

            return inserted.ContentDocumentId;
        }

        throw new AuraHandledException('Failed to fetch image: ' + res.getStatus());
    }
}

  
