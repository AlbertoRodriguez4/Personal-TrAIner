import { Controller, Get, Post, Body, Param, ParseUUIDPipe, Put, Delete, HttpCode, HttpStatus } from '@nestjs/common';
import { UserService } from '../service/user.service';
import { UserDto } from '../dto/user.dto';
import { UpdateUserDto } from '../dto/update-user.dto';
import { LoginDto } from '../dto/login.dto';
import { ChangePasswordDto } from '../dto/change-password.dto';
import { Public } from '../../auth/public.decorator';

@Controller('users')
export class UserController {
    constructor(private readonly userService: UserService) {}

    /**
     * Endpoint: POST http://localhost:3000/users/register
     * Recibe los datos del usuario, encripta la contraseña y lo guarda.
     */
    @Public()
    @Post('register')
    register(@Body() createUserDto: UserDto) {
        return this.userService.register(createUserDto);
    }

   
    @Public()
    @Post('login')
    @HttpCode(HttpStatus.OK)
    login(@Body() body: LoginDto) {
        return this.userService.login(body.email, body.password);
    }

    @Public()
    @Post('google-login')
    @HttpCode(HttpStatus.OK)
    googleLogin(@Body('idToken') idToken: string) {
        return this.userService.googleLogin(idToken);
    }

    // `POST /users` y `GET /users` se han retirado: el primero creaba usuarios
    // saltándose el hasheo de bcrypt que sí hace `register`, y el segundo
    // devolvía TODOS los usuarios con su hash de contraseña dentro. Ninguno de
    // los dos lo usa la app, y en una API pública son dos regalos.

    @Get(':id')
    findOne(@Param('id') id: string) {
        return this.userService.findOne(id);
    }

    /// Edición parcial. `UpdateUserDto` deja fuera la contraseña a propósito:
    /// ver el porqué en el propio DTO.
    @Put(':id')
    update(@Param('id') id: string, @Body() updateUserDto: UpdateUserDto) {
        return this.userService.update(id, updateUserDto);
    }

    /// La guarda ya comprueba que `:id` es el usuario del token (lo saca de la
    /// ruta `/users/<uuid>/…`), así que solo se puede cambiar la propia.
    @Put(':id/password')
    changePassword(
        @Param('id', ParseUUIDPipe) id: string,
        @Body() dto: ChangePasswordDto,
    ) {
        return this.userService.changePassword(id, dto);
    }

    @Delete(':id')
    remove(@Param('id') id: string) {
        return this.userService.remove(id);
    }
}