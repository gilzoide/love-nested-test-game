gravidade = 9.81 * METER_BY_PIXEL
paredes = {
    0, WINDOW_HEIGHT,
    0, 0,
    WINDOW_WIDTH, 0,
    WINDOW_WIDTH, WINDOW_HEIGHT,
}
chao = {
    0, WINDOW_HEIGHT,
    WINDOW_WIDTH, WINDOW_HEIGHT,
}

buneco1_x = WINDOW_WIDTH * 0.25
buneco2_x = WINDOW_WIDTH * 0.75
buneco_y = WINDOW_HEIGHT - Buneco.raio

peteca_init_x = WINDOW_WIDTH * 0.5
peteca_init_y = 100

function init()
    love.graphics.setBackgroundColor(0.12, 0.12, 0.12)
    esperando = true

    world = R('world', 'world', 0, gravidade)
    body = love.physics.newBody(world)
    paredes_shape = love.physics.newChainShape(false, unpack(paredes))
    paredes_fixture = love.physics.newFixture(body, paredes_shape)
    paredes_fixture:setRestitution(0.5)
    paredes_fixture:setFriction(1)
    chao_shape = love.physics.newEdgeShape(unpack(chao))
    chao_fixture = love.physics.newFixture(body, chao_shape)
    chao_fixture:setFriction(1)
    
    buneco1 = addchild(Buneco { x = buneco1_x, y = buneco_y, cor = {0, 1, 0}, tecla_esquerda = 'a', tecla_direita = 'd' })
    buneco2 = addchild(Buneco { x = buneco2_x, y = buneco_y, cor = {1, 1, 0}, flipX = true, tecla_esquerda = 'left', tecla_direita = 'right' })
    vida1 = addchild(Vida { cor = buneco1.cor })
    vida2 = addchild(Vida { cor = buneco2.cor, flipX = true })
    peteca = addchild(Peteca { x = peteca_init_x, y = peteca_init_y })
    placar = addchild(Placar {})

    also_when = {
        {{}, function()
            buneco2.tomou_dano = false
            vida2.tomou_dano = false
            buneco1.tomou_dano = false
            vida1.tomou_dano = false
        end},
        {{ { 'Collisions', 'postSolve', peteca.fixture, chao_fixture } }, function()
            local collinfo = nested.get(Collisions, 'postSolve', peteca.fixture, chao_fixture)
            if peteca.ultimo_a_bater == buneco1 then
                buneco2.tomou_dano = true
                vida2.tomou_dano = true
            elseif peteca.ultimo_a_bater == buneco2 then
                buneco1.tomou_dano = true
                vida1.tomou_dano = true
            end
            peteca.impulso(collinfo)
        end},

        {{ { 'Collisions', 'postSolve', peteca.fixture, buneco1.raquete_fixture } }, function()
            local collinfo = nested.get(Collisions, 'postSolve', peteca.fixture, buneco1.raquete_fixture)
            peteca.ultimo_a_bater = buneco1
            peteca.impulso(collinfo)
        end},
        {{ { 'Collisions', 'touching', peteca.fixture, buneco1.main_fixture } }, function()
            buneco1.tomou_dano = true
            vida1.tomou_dano = true
        end},
        {{ 'vida1.acabou', '!vida2.acabou' }, function()
            esperando = true
            placar.ganhador = 2
            placar.hidden = false
        end},

        {{ { 'Collisions', 'postSolve', peteca.fixture, buneco2.raquete_fixture } }, function()
            local collinfo = nested.get(Collisions, 'postSolve', peteca.fixture, buneco2.raquete_fixture)
            peteca.ultimo_a_bater = buneco2
            peteca.impulso(collinfo)
        end},
        {{ { 'Collisions', 'touching', peteca.fixture, buneco2.main_fixture } }, function()
            buneco2.tomou_dano = true
            vida2.tomou_dano = true
        end},
        {{ '!vida1.acabou', 'vida2.acabou' }, function()
            esperando = true
            placar.ganhador = 1
            placar.hidden = false
        end},
    }
end

function draw()

end

function reset()
    reset_peteca()
    reset_buneco(buneco1, buneco1_x)
    reset_buneco(buneco2, buneco2_x)
    world:update(1 / 60) -- roda possíveis contatos antes de resetar a vida
    vida1.reset()
    vida2.reset()
end
function reset_peteca()
    peteca.body:setPosition(peteca_init_x, peteca_init_y)
    peteca.body:setAngle(0)
    peteca.body:setAngularVelocity(0)
    peteca.body:setLinearVelocity(0, 0.1)
end
function reset_buneco(buneco, x)
    buneco.body:setPosition(x, buneco_y)
    buneco.body:setLinearVelocity(0, 0.1)
    buneco.body:setAngle(0)
    buneco.body:setAngularVelocity(0)
end

when = {
    {{ '!esperando' }, function()
        world:update(dt)
    end},
    {{ 'esperando', 'Input.keypressed.return' }, function()
        esperando = false
        placar.hidden = true
        reset()
    end},

    {{ 'DEBUG' }, function()
        if Input.keypressed.r then
            if love.keyboard.isDown('lshift', 'rshift') then
                reset()
            else
        reset_peteca()
            end
        elseif Input.keypressed[1] then
            vida2.acabou = true
        elseif Input.keypressed[2] then
            vida1.acabou = true
        end
    end},
}