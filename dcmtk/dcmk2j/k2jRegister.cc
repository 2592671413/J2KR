#include "dcmtk/config/osconfig.h"
#include "dcmtk/dcmk2j/k2jRegister.h"

#include "dcmtk/dcmdata/dccodec.h"  /* for DcmCodecStruct */

#include "dcmtk/dcmk2j/dccodec/udk/udk.h"

// initialization of static members
OFBool k2jRegister::registered                       = OFFalse;
k2jParams *k2jRegister::cp                           = NULL;
udk *k2jRegister::dec2KLoL                           = NULL;

void k2jRegister::registerCodecs(
    E_DecompressionColorSpaceConversion pDecompressionCSConversion,
    E_UIDCreation pCreateSOPInstanceUID,
    E_PlanarConfiguration pPlanarConfiguration,
    OFBool predictor6WorkaroundEnable)
{
  if (! registered)
  {
    cp = new k2jParams(
      ECC_lossyYCbCr, // ignored, compression only
      pDecompressionCSConversion, 
      pCreateSOPInstanceUID, 
      pPlanarConfiguration,
      predictor6WorkaroundEnable);
    if (cp)
    {
      dec2KLoL = new udk();
      if (dec2KLoL) DcmCodecList::registerCodec(dec2KLoL, NULL, cp);

      registered = OFTrue;
    }
  }
}

void k2jRegister::cleanup()
{
  if (registered)
  {
    delete cp;
    DcmCodecList::deregisterCodec(dec2KLoL);
    delete dec2KLoL;
    registered = OFFalse;
#ifdef DEBUG
    // not needed but useful for debugging purposes
    dec2KLol = NULL;
    cp     = NULL;
#endif

  }
}
