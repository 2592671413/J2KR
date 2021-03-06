#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>//for md5

#undef verify
#include "dcmtk/config/osconfig.h"
#include "dcmtk/oflog/oflog.h"
#include "dcmtk/dcmdata/dcdatset.h"
#include "dcmtk/dcmdata/dcmetinf.h"
#include "dcmtk/dcmdata/dcfilefo.h"
#include "dcmtk/dcmdata/dcdict.h"
#include "dcmtk/dcmdata/dcdeftag.h"

//jpeg
#include "dcmtk/dcmjpeg/djdecode.h"
#include "dcmtk/dcmjpeg/djencode.h"
#include "dcmtk/dcmjpeg/djcparam.h"

//jpls
#include "dcmtk/dcmjpls/djdecode.h"
#include "dcmtk/dcmjpls/djencode.h"

//k2j
#include "dcmtk/dcmk2j/k2jRegister.h"

//rk2j
#include "dcmtk/dcmrk2j/rk2jRegister.h"

//j2kr
#include "dcmtk/dcmj2kr/j2krRegister.h"
#include "dcmtk/dcmj2kr/kdur/kdurParams.h"
#include "dcmtk/dcmj2kr/opjr/opjrParams.h"

enum baseArgs {
    codec=1,
    fileRelativePath,
    inBasePath,
    doneBasePath,
    errBasePath,
    logVerbosity,
};

//JF extern void dcmtkSetJPEGColorSpace( int);

static NSFileManager *fileManager=nil;
static NSError *err=nil;
static BOOL kakaduReversible=false;
static BOOL kakadu=false;
static BOOL openjpegReversible=false;
static BOOL kakaduReversibleDecode=false;
static BOOL kakaduDecode=false;
static BOOL openjpegReversibleDecode=false;

BOOL folderExists(NSString *f, BOOL shouldBeEmptyAndWritable)
{
    NSString *folderPath=[f stringByExpandingTildeInPath];
    BOOL isFolder=false;
    BOOL exists=[fileManager fileExistsAtPath:folderPath isDirectory:&isFolder];

    
    if (!exists)
    {
        [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:&err];
        if (![fileManager fileExistsAtPath:folderPath])
        {
            NSLog(@"could not create: %@",folderPath);
            return false;
        }
        return true;
    }
    else if (!isFolder)
    {
        NSLog(@"is not folder: %@",folderPath);
        return false;
    }
    else if (shouldBeEmptyAndWritable)
    {
        NSArray *array=[fileManager contentsOfDirectoryAtPath:folderPath error:nil];
        for (NSString *name in array)
        {
            if (![name hasPrefix:@"."])
            {
                NSLog(@"%@ INITIALLY NOT empty\r\nContains: %@",folderPath,name);
                return false;
            }
        }

#pragma mark --- missing writability check ---
    }
    return true;
}

NSString* attrStringValue(DcmDataset *dataset, short g, short e, NSStringEncoding c)
{
    const char *s = NULL;
    if (dataset->findAndGetString(DcmTagKey(g,e), s, OFFalse).good() && s != NULL)
        return [NSString stringWithCString:s encoding:c];
    return nil;
}

int main(int argc, const char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSString *syntax=@"syntax:\r\nJ2KR\r\n[1]codec\r\n\t[1]inRelativePathOr*\r\n\t[2]inBasePath/\r\n\t[3]doneBasePath/\r\n\t[4]errBasePath/\r\n\t[5] FATAL_LOG_LEVEL, ERROR_LOG_LEVEL, WARN_LOG_LEVEL, INFO_LOG_LEVEL, DEBUG_LOG_LEVEL, TRACE_LOG_LEVEL";
    //\r\n[6..]opt\r\n
    //\t!\"attrPath\" (delete attribute)\r\n
    //\t!\"attrPath\"!{\"Value\":[]} (delete attribute contents)\r\n
    //\t!\"attrPath\"!{\"Value\":[a,b]} (delete values a and b from the values of the attribute)\r\n
    //\t+\"attrPath\"+{\"vr\":\"xx\"} (add empty attribute, if it does not exist)\r\n
    //\t+\"attrPath\"+{\"vr\":\"xx\",\"Value\":[a,b]} (add values a, b to attribute)
    //\r\n
    //\r\n
    //attrPath=ggggeeee[.0001-ggggeeee][..]\r\n
    //deletes performed before additions\r\n
    
    NSMutableArray *args=[NSMutableArray arrayWithArray:[[NSProcessInfo processInfo] arguments]];
    NSUInteger argsCount=[args count];
    if (argsCount<7) {NSLog(@"%@",syntax);return 1;}

    fileManager=[NSFileManager defaultManager];

    kakadu=[args[codec] isEqualToString:@"kdu"];
    kakaduReversible=[args[codec] isEqualToString:@"kdur"];
    openjpegReversible=[args[codec] isEqualToString:@"opjr"];
    kakaduDecode=[args[codec] isEqualToString:@"udk"];
    kakaduReversibleDecode=[args[codec] isEqualToString:@"rudk"];
    openjpegReversibleDecode=[args[codec] isEqualToString:@"rjpo"];
#pragma mark arg[5] log level
    enum loglevel {
        FATAL_LOG_LEVEL,
        ERROR_LOG_LEVEL,
        WARN_LOG_LEVEL,
        INFO_LOG_LEVEL,
        DEBUG_LOG_LEVEL,
        TRACE_LOG_LEVEL,
    };
    BOOL FATAL=false;
    BOOL ERROR=false;
    BOOL WARN=false;
    BOOL INFO=false;
    BOOL DEBUG=false;
    BOOL TRACE=false;
    if      ([args[logVerbosity] isEqualToString:@"FATAL_LOG_LEVEL"])
    {
        OFLog::configure(OFLogger::FATAL_LOG_LEVEL);
        FATAL=true;
    }
    else if ([args[logVerbosity] isEqualToString:@"ERROR_LOG_LEVEL"])
    {
        OFLog::configure(OFLogger::ERROR_LOG_LEVEL);
        FATAL=true;
        ERROR=true;
    }
    else if ([args[logVerbosity] isEqualToString:@"WARN_LOG_LEVEL"])
    {
        OFLog::configure(OFLogger::WARN_LOG_LEVEL);
        FATAL=true;
        ERROR=true;
        WARN=true;
    }
    else if ([args[logVerbosity] isEqualToString:@"INFO_LOG_LEVEL"])
    {
        OFLog::configure(OFLogger::INFO_LOG_LEVEL);
        FATAL=true;
        ERROR=true;
        WARN=true;
        INFO=true;
    }
    else if ([args[logVerbosity] isEqualToString:@"DEBUG_LOG_LEVEL"])
    {
        OFLog::configure(OFLogger::DEBUG_LOG_LEVEL);
        FATAL=true;
        ERROR=true;
        WARN=true;
        INFO=true;
        DEBUG=true;
    }
    else if ([args[logVerbosity] isEqualToString:@"TRACE_LOG_LEVEL"])
    {
        OFLog::configure(OFLogger::TRACE_LOG_LEVEL);
        FATAL=true;
        ERROR=true;
        WARN=true;
        INFO=true;
        DEBUG=true;
        TRACE=true;
    }
    else
    {
        NSLog(@"log verbosity (arg[5] required to be one of FATAL_LOG_LEVEL, ERROR_LOG_LEVEL, WARN_LOG_LEVEL, INFO_LOG_LEVEL, DEBUG_LOG_LEVEL, TRACE_LOG_LEVEL");
        return 1;//exit error
    }

//--------------------------------------------------------------------------
    
#pragma mark args[2-5] paths
    NSArray *r;
    if (
           [args[fileRelativePath] isEqualToString:@"*"]
        ||!(r=[fileManager contentsOfDirectoryAtPath:[args[inBasePath]stringByExpandingTildeInPath] error:&err])
        )
    {
        NSLog(@"could not get contents of %@\r%@",args[inBasePath],[err description]);
        return 1;
    }
    else
    {
        BOOL isDirectory=true;
        if (([fileManager fileExistsAtPath:[[args[inBasePath]stringByExpandingTildeInPath]stringByAppendingPathComponent:args[fileRelativePath]] isDirectory:&isDirectory]) && !isDirectory)
            r=@[args[fileRelativePath]];
        else
        {
            NSLog(@"no %@ in %@",args[fileRelativePath],args[inBasePath]);
            return 1;
        }
        
    }
    
    NSString *iFolder=[args[inBasePath]stringByExpandingTildeInPath];
    NSString *oFolder=[args[doneBasePath]stringByExpandingTildeInPath];
    NSString *eFolder=[args[errBasePath]stringByExpandingTildeInPath];
    if(
         !folderExists(oFolder,true)
       ||!folderExists(eFolder,true)
       )
        return 1;//exit error

    
//--------------------------------------------------------------------------
#pragma mark args[6..] optional (delete/add)
    
    NSMutableDictionary *dDict=[NSMutableDictionary dictionary];
    NSMutableDictionary *aDict=[NSMutableDictionary dictionary];
    for (int i=5;i<argsCount;i++)
    {
        if ([args[i] hasPrefix:@"!"])
        {
            NSMutableArray *remove=[NSMutableArray arrayWithArray:[args[i] componentsSeparatedByString:@"!"]];
            switch ([remove count]) {
                case 2:
                    [dDict setObject:[NSNull null] forKey:remove[1]];
                    break;
                case 3:
                    [dDict setObject:remove[2] forKey:remove[1]];
                    break;
                default:
                    NSString *attrPath=[NSString stringWithString:remove[1]];
                    [remove removeObjectAtIndex:1];
                    [remove removeObjectAtIndex:0];
                    [dDict setObject:[remove componentsJoinedByString:@"!"] forKey:attrPath];
                    break;
            }
            continue;
        }
        if ([args[i] hasPrefix:@"+"])
        {
            NSMutableArray *add=[NSMutableArray arrayWithArray:[args[i] componentsSeparatedByString:@"+"]];
            switch ([add count]) {
                case 2:
                    [aDict setObject:[NSNull null] forKey:add[1]];
                    break;
                case 3:
                    [aDict setObject:add[2] forKey:add[1]];
                    break;
                default:
                    NSString *attrPath=[NSString stringWithString:add[1]];
                    [add removeObjectAtIndex:1];
                    [add removeObjectAtIndex:0];
                    [aDict setObject:[add componentsJoinedByString:@"+"] forKey:attrPath];
                    break;
            }
            continue;
        }
    }

//--------------------------------------------------------------------------
#pragma mark encoders registration
    
    DJEncoderRegistration::registerCodecs();
    DJLSEncoderRegistration::registerCodecs();

    j2krRegister::registerCodecs();
    //DcmRLEEncoderRegistration::registerCodecs();

    
//--------------------------------------------------------------------------
#pragma mark decoders registration

    DJDecoderRegistration::registerCodecs(
        EDC_photometricInterpretation,//E_DecompressionColorSpaceConversion [EDC_photometricInterpretation, EDC_lossyOnly,EDC_always,EDC_never,EDC_guessLossyOnly,EDC_guess]
        EUC_never,//E_UIDCreation [EUC_default,EUC_always,EUC_never]
        EPC_default,//E_PlanarConfiguration [EPC_default,EPC_colorByPixel,EPC_colorByPlane]
        OFFalse //OFBool predictor6WorkaroundEnable [OFFalse,OFTrue]
    );

    DJLSDecoderRegistration::registerCodecs();

    k2jRegister::registerCodecs(
        EDC_photometricInterpretation,//E_DecompressionColorSpaceConversion [EDC_photometricInterpretation, EDC_lossyOnly,EDC_always,EDC_never,EDC_guessLossyOnly,EDC_guess]
        EUC_never,//E_UIDCreation [EUC_default,EUC_always,EUC_never]
        EPC_default,//E_PlanarConfiguration [EPC_default,EPC_colorByPixel,EPC_colorByPlane]
        OFFalse //OFBool predictor6WorkaroundEnable [OFFalse,OFTrue]
    );
    
    rk2jRegister::registerCodecs(
        EDC_photometricInterpretation,//E_DecompressionColorSpaceConversion [EDC_photometricInterpretation, EDC_lossyOnly,EDC_always,EDC_never,EDC_guessLossyOnly,EDC_guess]
        EUC_never,//E_UIDCreation [EUC_default,EUC_always,EUC_never]
        EPC_default,//E_PlanarConfiguration [EPC_default,EPC_colorByPixel,EPC_colorByPlane]
        OFFalse //OFBool predictor6WorkaroundEnable [OFFalse,OFTrue]
                                );

    //DcmRLEDecoderRegistration::registerCodecs();
    
    
    if (DEBUG)
    {
        //http://www.dicomlibrary.com/dicom/transfer-syntax/
        
        fprintf(stdout,"D: additional encoders registered [\r\n");
        
        /*
        //we removed the private character of encoding codec registrations

        if (DJEncoderRegistration::encbas != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.50) dcmtk ijg encbas \r\n");
        if (DJEncoderRegistration::encext != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.51) dcmtk ijg encext \r\n");
        if (DJEncoderRegistration::encsps != NULL) fprintf(stdout,"      (Retired)                dcmtk ijg encsps\r\n");
        if (DJEncoderRegistration::encpro != NULL) fprintf(stdout,"      (Retired)                dcmtk ijg encpro\r\n");
        if (DJEncoderRegistration::encsv1 != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.70) dcmtk ijg encsv1 \r\n");
        if (DJEncoderRegistration::enclol != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.57) dcmtk ijg enclol \r\n");
         */

        if (j2krRegister::kakaduReversible != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.90) dcmtk kakaduReversible \r\n");
        if (j2krRegister::openjpegReversible != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.90) dcmtk openjpegReversible \r\n");
        /*
        if (DJLSEncoderRegistration::registered_==OFTrue)
        {            
            if (DJLSEncoderRegistration::losslessencoder_ != nullptr) fprintf(stdout,"      (1.2.840.10008.1.2.4.80) %s losslessencoder \r\n",DJLSEncoderRegistration::getLibraryVersionString().c_str());
            if (DJLSEncoderRegistration::nearlosslessencoder_ != nullptr) fprintf(stdout,"      (1.2.840.10008.1.2.4.81) %s nearlosslessencoder \r\n",DJLSEncoderRegistration::getLibraryVersionString().c_str());
        }
         */
        fprintf(stdout,"   ]\r\n");

        
        fprintf(stdout,"D: additional decoders registered [\r\n");
        /*
        //we removed the private character of encoding codec registrations
        if (DJDecoderRegistration::decbas != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.50) dcmtk ijg encbas \r\n");
        if (DJDecoderRegistration::decext != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.51) dcmtk ijg encext \r\n");
        if (DJDecoderRegistration::decsps != NULL) fprintf(stdout,"      (Retired)                dcmtk ijg encsps\r\n");
        if (DJDecoderRegistration::decpro != NULL) fprintf(stdout,"      (Retired)                dcmtk ijg encpro\r\n");
        if (DJDecoderRegistration::decsv1 != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.70) dcmtk ijg encsv1 \r\n");
        if (DJDecoderRegistration::declol != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.57) dcmtk ijg enclol \r\n");
         */
        if (k2jRegister::kakaduReversibleDecode != NULL) fprintf(stdout,"      (1.2.840.10008.1.2.4.90) kdu kakaduReversible \r\n");
        /*
        if (DJLSEncoderRegistration::registered_==OFTrue)
        {
            if (DJLSEncoderRegistration::losslessencoder_ != nullptr) fprintf(stdout,"      (1.2.840.10008.1.2.4.80) %s losslessencoder \r\n",DJLSEncoderRegistration::getLibraryVersionString().c_str());
            if (DJLSEncoderRegistration::nearlosslessencoder_ != nullptr) fprintf(stdout,"      (1.2.840.10008.1.2.4.81) %s nearlosslessencoder \r\n",DJLSEncoderRegistration::getLibraryVersionString().c_str());
        }
         */
        fprintf(stdout,"   ]\r\n");
    
    
    }

    
#pragma mark -for each file
    for( NSString *relFilePath in r)
    {
        if ([[relFilePath lastPathComponent] hasPrefix:@"."])continue;

        NSString *i=[iFolder stringByAppendingPathComponent:relFilePath];
        NSString *o=[oFolder stringByAppendingPathComponent:relFilePath];
        NSString *e=[eFolder stringByAppendingPathComponent:relFilePath];

#pragma mark read
        
        DcmFileFormat fileformat;
        OFCondition cond = fileformat.loadFile( [i UTF8String]);//requires libiconv
        if(!cond.good())
        {
            NSLog(@"symlink in err (can not read: %@)",i);
            //myunlink([i fileSystemRepresentation]);
            if (![fileManager createSymbolicLinkAtPath:e
                                   withDestinationPath:i
                                                 error:&err]
                );
#pragma mark ??? fileformat. delete ;
                NSLog(@"can not make symlink: %@\r\n%@",e,[err description]);
            continue;
        }

        //�needs to be unlinked, at least before moving it around?
#pragma mark parse
        DcmDataset *dataset = fileformat.getDataset();
        DcmXfer original_xfer(dataset->getOriginalXfer());
        
        if (original_xfer.isEncapsulated())
        {
            NSLog(@"[symlink in done (already compressed:%@)",i);
            //myunlink([i fileSystemRepresentation]);
            if (![fileManager createSymbolicLinkAtPath:o
                                   withDestinationPath:i
                                                 error:&err]
                )
                NSLog(@"can not make symlink: %@\r\n%@",e,[err description]);
            continue;
        }

#pragma mark apply opt args
        
         //NSString *sopInstanceUID=attrStringValue(dataset, 0x0008, 0x0018, NSASCIIStringEncoding);
         //NSString *studyInstanceUID=attrStringValue(dataset, 0x0020, 0x000D, NSASCIIStringEncoding);
         //remove NameofPhysiciansReadingStudy (custom3 is already filled with chosen radiologist)
         delete dataset->remove( DcmTagKey( 0x0008, 0x1060));
         //remove SQ reqService (custom2 is already filled with chosen requesting institution)
         delete dataset->remove( DcmTagKey( 0x0032, 0x1034));
         
         // "GEIIS" The problematic private group, containing a *always* JPEG compressed PixelData
         delete dataset->remove( DcmTagKey( 0x0009, 0x1110));
        

#pragma mark delete operations
        for (NSString *tagPath in [dDict allKeys])
        {
            id object=[dDict objectForKey:tagPath];
            if (object==[NSNull null])
            {
                NSLog(@"delete the attribute: %@",tagPath);
            }
            else
            {
                NSData *jsonData=[object dataUsingEncoding:NSUTF8StringEncoding];
                id jsonObject=[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&err];
                if (err)
                {
                    NSLog(@"%@\r\n%@\r\n%@",tagPath,[dDict objectForKey:tagPath],[err description]);
                    err=nil;
                    continue;
                }
                
                if (![jsonObject isKindOfClass:[NSDictionary class]])
                {
                    NSLog(@"%@\r\n%@\r\n%@",tagPath,[dDict objectForKey:tagPath],[err description]);
                    err=nil;
                    continue;
                }
                //there is a dictionary
                id value=[jsonObject valueForKey:@"Value"];
                if ([value isKindOfClass:[NSArray class]])
                {
                    if (![value count])
                    {
                        NSLog(@"delete all values of attribute: %@",tagPath);
                    }
                    else
                    {
                        NSLog(@"delete %@ of attribute: %@", [value description],tagPath);
                    }
                }
            }
        }
        
        
#pragma mark additions
        for (NSString *tagPath in [aDict allKeys])
        {
            id object=[dDict objectForKey:tagPath];
            NSData *jsonData=[object dataUsingEncoding:NSUTF8StringEncoding];
            id jsonObject=[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&err];
            if (err)
            {
                NSLog(@"%@\r\n%@\r\n%@",tagPath,[dDict objectForKey:tagPath],[err description]);
                err=nil;
                continue;
            }
            
            if (![jsonObject isKindOfClass:[NSDictionary class]])
            {
                NSLog(@"%@\r\n%@\r\n%@",tagPath,[dDict objectForKey:tagPath],[err description]);
                err=nil;
                continue;
            }
            //there is a dictionary
            id value=[jsonObject valueForKey:@"Value"];
            if ([value isKindOfClass:[NSString class]])
            {
                if (![value count])
                {
                    NSLog(@"delete all values of attribute: %@",tagPath);
                }
                else
                {
                    NSLog(@"delete %@ of attribute: %@", [value description],tagPath);
                }
            }
        }

#pragma mark J2KR
        //encode
        /*
         DcmDatset.cc 694-698
         pixelStack.top().top())->
         chooseRepresentation(repType, repParam, pixelStack.top()
         
         dcpixel.cc 274ss
         encode((*original)->repType, (*original)->repParam,
         (*original)->pixSeq, toType, repParam, pixelStack)
         
         */
        
        DcmRepresentationParameter *params;
        if (kakaduReversible)
        {
            kdurParams JP2KParamsLossLess(0);
            params = &JP2KParamsLossLess;
        }
        else if (openjpegReversible)
        {
            opjrParams JP2KParamsLossLess(0);
            params = &JP2KParamsLossLess;
        }        
        dataset->chooseRepresentation(EXS_JPEG2000LosslessOnly, params);
        
        fileformat.loadAllDataIntoMemory();
        if (dataset->canWriteXfer(EXS_JPEG2000LosslessOnly))
        {
           cond = fileformat.saveFile([o UTF8String], EXS_JPEG2000LosslessOnly);
        }
        else NSLog(@"NOT possible EXS_JPEG2000LosslessOnly");
#pragma mark JPEG Baseline lossy
        /*
        DJ_RPLossy param;
        dataset->chooseRepresentation(EXS_JPEGProcess1, &param);
        if (dataset->canWriteXfer(EXS_JPEGProcess1))
        {
            NSLog(@"possible JPEGProcess1");
        }
        else NSLog(@"not possible JPEGProcess1");
        fileformat.loadAllDataIntoMemory();
        cond = fileformat.saveFile([o UTF8String], EXS_JPEGProcess1);//EXS_LittleEndianExplicit);//
         */
    }
    [pool release];
    return 0;

}
