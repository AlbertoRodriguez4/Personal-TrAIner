import { Controller, Get, Post, Body, Param, Put, Delete, HttpCode, HttpStatus } from '@nestjs/common';
import { UserService } from '../service/user.service';
import { UserDto } from '../dto/user.dto';

@Controller('users')
export class UserController {
    constructor(private readonly userService: UserService) {}

    /**
     * Endpoint: POST http://localhost:3000/users/register
     * Recibe los datos del usuario, encripta la contraseña y lo guarda.
     */
    @Post('register')
    register(@Body() createUserDto: UserDto) {
        return this.userService.register(createUserDto);
    }

   
    @Post('login')
    @HttpCode(HttpStatus.OK) 
    login(@Body() body: { email: string; password: string }) {
        return this.userService.login(body.email, body.password);
    }

    @Post()
    create(@Body() createUserDto: UserDto) {
        return this.userService.create(createUserDto);
    }

    @Get()
    findAll() {
        return this.userService.findAll();
    }

    @Get(':id')
    findOne(@Param('id') id: string) {
        return this.userService.findOne(id);
    }

    @Put(':id')
    update(@Param('id') id: string, @Body() updateUserDto: UserDto) {
        return this.userService.update(id, updateUserDto);
    }

    @Delete(':id')
    remove(@Param('id') id: string) {
        return this.userService.remove(id);
    }
}