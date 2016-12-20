/*
 *  Copyright (C) 2001-2010, OFFIS e.V.
 *  All rights reserved.  See COPYRIGHT file for details.
 *  This software and supporting documentation were developed by
 *    OFFIS e.V.
 *    R&D Division Health
 *    Escherweg 2
 *    D-26121 Oldenburg, Germany
 *  Module:  dcmjpeg
 *  Author:  Marco Eichelberg
 *  Purpose: Codec class for decoding JPEG Spectral Selection (lossy, 8/12-bit)
 */

#include "dcmtk/config/osconfig.h"
#include "dcmtk/dcmjpeg/dec/ijg/sps/djdecsps.h"
#include "dcmtk/dcmdataImplementation/dccodec/djcparam.h"
#include "dcmdataImplementation/dcpixel/jpegParams.h"
#include "dcmtk/dcmjpeg/dec/ijg/djdijg8.h"
#include "dcmtk/dcmjpeg/dec/ijg/djdijg12.h"


DJDecoderSpectralSelection::DJDecoderSpectralSelection()
: DJCodecDecoder()
{
}


DJDecoderSpectralSelection::~DJDecoderSpectralSelection()
{
}


E_TransferSyntax DJDecoderSpectralSelection::supportedTransferSyntax() const
{
  return EXS_JPEGProcess6_8;
}


DJDecoder *DJDecoderSpectralSelection::createDecoderInstance(
    const DcmRepresentationParameter * /* toRepParam */,
    const DJCodecParameter *cp,
    Uint8 bitsPerSample,
    OFBool isYBR) const
{
  if (bitsPerSample > 8) return new DJDecompressIJG12Bit(*cp, isYBR);
  else return new DJDecompressIJG8Bit(*cp, isYBR);
}
