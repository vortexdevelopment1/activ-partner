import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';

export interface PostOffice {
  name: string;
  branchType: string;
  deliveryStatus: string;
  district: string;
  division: string;
  state: string;
  pincode: string;
}

export interface PincodeResult {
  pincode: string;
  city: string;
  state: string;
  postOffices: PostOffice[];
}

@Injectable()
export class LocationService {
  private readonly PINCODE_API = 'https://api.postalpincode.in/pincode';

  async lookupPincode(pincode: string): Promise<PincodeResult> {
    if (!/^\d{6}$/.test(pincode)) {
      throw new BadRequestException('Pincode must be exactly 6 digits');
    }

    let data: any[];
    try {
      const response = await fetch(`${this.PINCODE_API}/${pincode}`);
      data = await response.json() as any[];
    } catch {
      throw new BadRequestException('Failed to reach pincode lookup service. Please try again.');
    }

    const result = data?.[0];
    if (!result || result.Status !== 'Success' || !result.PostOffice?.length) {
      throw new NotFoundException(`No details found for pincode ${pincode}`);
    }

    const postOffices: PostOffice[] = result.PostOffice.map((po: any) => ({
      name: po.Name,
      branchType: po.BranchType,
      deliveryStatus: po.DeliveryStatus,
      district: po.District,
      division: po.Division,
      state: po.State,
      pincode: po.Pincode,
    }));

    return {
      pincode,
      city: result.PostOffice[0].District,
      state: result.PostOffice[0].State,
      postOffices,
    };
  }
}
