import { validate } from 'class-validator';
import { CreateTeamMemberDto } from './create-team-member.dto';
import { UpdateTeamMemberDto } from './update-team-member.dto';
import { TeamMemberRole } from '../../../common/enums/team-member-role.enum';

describe.each([CreateTeamMemberDto, UpdateTeamMemberDto])('%s phone validation', (Dto) => {
  it.each(['+916123456789', '+917123456789', '+918123456789', '+919876543210', '+14155552671'])('accepts %s', async (phone) => {
    const dto = Object.assign(new Dto(), { fullName: 'Test Member', role: TeamMemberRole.MANAGER, phone });
    expect(await validate(dto)).toEqual([]);
  });

  it.each(['+91747065099400', '+915123456789', '+91987654321', '9876543210', '+9198765432100', '+91abcdefghij', '+91 9876543210'])('rejects %s', async (phone) => {
    const dto = Object.assign(new Dto(), { fullName: 'Test Member', role: TeamMemberRole.MANAGER, phone });
    expect((await validate(dto)).some((error) => error.property === 'phone')).toBe(true);
  });
});
