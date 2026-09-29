import {
  Controller,
  Post,
  Body,
  Get,
  UseGuards,
  HttpCode,
  HttpStatus,
  Patch,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { RegisterPartnerDto } from './dto/register-partner.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { CompletePartnerProfileDto } from './dto/complete-partner-profile.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { User } from '../users/entities/user.entity';
import { Partner } from '../partners/entities/partner.entity';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login for all users (admin/partner/user)' })
  async login(@Body() loginDto: LoginDto) {
    const data = await this.authService.login(loginDto);
    return { message: 'Login successful', data };
  }

  @Public()
  @Post('register')
  @ApiOperation({ summary: 'Register a new user' })
  async registerUser(@Body() registerDto: RegisterDto) {
    const data = await this.authService.registerUser(registerDto);
    return { message: 'User registered successfully', data };
  }

  @Public()
  @Post('register/partner')
  @ApiOperation({ summary: 'Register as a venue partner (email/password flow)' })
  async registerPartner(@Body() registerPartnerDto: RegisterPartnerDto) {
    const data = await this.authService.registerPartner(registerPartnerDto);
    return { message: 'Partner registered successfully', data };
  }

  @Public()
  @Post('partner/login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Login for partners only',
    description: 'Authenticates a partner using email and password. Returns partner profile along with JWT token.',
  })
  async partnerLogin(@Body() loginDto: LoginDto) {
    const data = await this.authService.partnerLogin(loginDto);
    return { message: 'Login successful', data };
  }

  // ─── Forgot Password Flow (Partner) ──────────────────────────────────────

  @Public()
  @Post('partner/forgot-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Step 1 — Request a password reset code via email',
    description: 'Sends a 4-digit reset code to the partner\'s registered email address, valid for 10 minutes.',
  })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    const data = await this.authService.forgotPassword(dto);
    return { message: data.message, data };
  }

  @Public()
  @Post('partner/reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Step 2 — Reset password using the emailed code',
    description: 'Submit email + reset code + new password to complete the reset.',
  })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    const data = await this.authService.resetPassword(dto);
    return { message: data.message, data };
  }

  // ─── Phone OTP Flow ───────────────────────────────────────────────────────

  @Public()
  @Post('partner/request-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Step 1 — Request OTP for partner phone registration',
    description:
      'Send your phone number to receive an OTP via SMS (delivered through MSG91). ' +
      'If MSG91_OTP_ENABLED=false on the server, no SMS is sent and the OTP is the last 4 digits of the phone number (dev/mock mode).',
  })
  async requestOtp(@Body() dto: RequestOtpDto) {
    const data = await this.authService.requestOtp(dto);
    return { message: 'OTP sent successfully', data };
  }

  @Public()
  @Post('partner/verify-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Step 2 — Verify OTP and receive JWT token',
    description:
      'Submit phone number + OTP. Returns JWT `accessToken`. Use this token in Step 3 to complete your profile.',
  })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    const data = await this.authService.verifyOtp(dto);
    return { message: 'OTP verified successfully', data };
  }

  @Public()
  @Post('partner/resend-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Resend OTP to a phone number that already has a pending verification',
    description: 'Retries delivery via MSG91 for an OTP that was already requested via Step 1.',
  })
  async resendOtp(@Body() dto: RequestOtpDto) {
    const data = await this.authService.resendOtp(dto);
    return { message: 'OTP resent successfully', data };
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Patch('partner/complete-profile')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Step 3 — Complete partner profile (requires JWT from Step 2)',
    description:
      'Update full name, email address, business name and contact number. Requires Bearer token from Step 2.',
  })
  async completePartnerProfile(
    @CurrentUser() user: User,
    @Body() dto: CompletePartnerProfileDto,
  ) {
    const data = await this.authService.completePartnerProfile(user.id, dto);
    return { message: 'Profile completed successfully', data };
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('partner/auth-profile')
  @ApiOperation({
    summary: 'Get partner profile using JWT token',
    description: 'Pass your Bearer token to retrieve partner profile data. Returns the same response as verify-otp.',
  })
  async getPartnerAuthProfile(@CurrentUser() partner: Partner) {
    const data = await this.authService.getPartnerAuthProfile(partner);
    return { message: 'Profile fetched successfully', data };
  }

  // ─────────────────────────────────────────────────────────────────────────

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('profile')
  @ApiOperation({ summary: 'Get current user profile' })
  async getProfile(@CurrentUser() user: User) {
    const data = await this.authService.getProfile(user.id);
    return { message: 'Profile fetched successfully', data };
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Patch('change-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Change password (User / Admin)' })
  async changePassword(
    @CurrentUser() user: User,
    @Body() changePasswordDto: ChangePasswordDto,
  ) {
    const data = await this.authService.changePassword(user.id, changePasswordDto);
    return { message: 'Password changed successfully', data };
  }

  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @Patch('partner/change-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Change password — venue partner',
    description:
      'Allows a venue partner to update their own account password using their JWT. ' +
      'Validates the current password before applying the new one.',
  })
  async changePartnerPassword(
    @CurrentUser() partner: Partner,
    @Body() dto: ChangePasswordDto,
  ) {
    const data = await this.authService.changePartnerPassword(partner.id, dto);
    return { message: 'Password changed successfully', data };
  }
}
