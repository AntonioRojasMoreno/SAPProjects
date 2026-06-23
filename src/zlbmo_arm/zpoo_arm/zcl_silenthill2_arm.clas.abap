CLASS zcl_silenthill2_arm DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Custom type for health values  (0-100)
    " Tipo propio para valores de salud (0-100)
    TYPES ty_health TYPE i.

    " Static counter of Pyramid Head encounters - READ-ONLY from outside
    " Contador estatico de encuentros con Pyramid Head - READ-ONLY desde fuera
    CLASS-DATA pyramid_head_encounters TYPE i READ-ONLY.

    " Static constructor - runs ONLY ONCE before any instance is created
    " Constructor estatico - se ejecuta UNA SOLA VEZ antes de cualquier instancia
    CLASS-METHODS class_constructor.

    " Factory method - validates inputs and returns a ready-to-use instance
    " Eclipse needs a parameterless constructor to run main via F9
    " so all validation lives here instead of in the constructor
    " Metodo factory - valida los datos y devuelve una instancia lista para usar
    " Eclipse necesita un constructor sin parametros para ejecutar main con F9
    " por eso toda la validacion vive aqui en lugar de en el constructor
    CLASS-METHODS create
      IMPORTING
        i_name     TYPE string
        i_health   TYPE ty_health
        i_location TYPE string
      RETURNING
        VALUE(ro_char) TYPE REF TO zcl_silenthill2_arm
      RAISING
        cx_abap_invalid_value.

    " Heals the character based on item type: Health Drink +25, Health Pack +50
    " Also removes the item from inventory automatically
    " Cura al personaje segun el item: Health Drink +25, Health Pack +50
    " Tambien elimina el item del inventario automaticamente
    METHODS heal
      IMPORTING
        i_item TYPE string
      RAISING
        cx_abap_invalid_value.

    " Adds an item to the character inventory
    " Agrega un item al inventario del personaje
    METHODS add_item
      IMPORTING
        i_item TYPE string
      RAISING
        cx_abap_invalid_value.

    " Removes an item from inventory and returns whether it was found
    " Elimina un item del inventario y devuelve si fue encontrado
    METHODS use_item
      IMPORTING
        i_item        TYPE string
      RETURNING
        VALUE(r_used) TYPE abap_bool.

    " Registers a Pyramid Head encounter and inflicts damage
    " Registra un encuentro con Pyramid Head e inflige danyo
    METHODS pyramid_head_encounter
      IMPORTING
        i_damage TYPE ty_health.

    " Adds a status effect to the character: POISON or BLIND
    " Agrega un efecto de estado al personaje: POISON o BLIND
    METHODS add_status_effect
      IMPORTING
        i_effect TYPE string
      RAISING
        cx_abap_invalid_value.

    " Removes an active status effect from the character
    " Elimina un efecto de estado activo del personaje
    METHODS remove_status_effect
      IMPORTING
        i_effect TYPE string.

    " Simulates time passing and applies all active status effect damage
    " Poison: -1 HP per minute, -5 max HP every 10 minutes
    " Simula el paso del tiempo y aplica el danyo de efectos de estado activos
    " Veneno: -1 HP por minuto, -5 HP maximo cada 10 minutos
    METHODS apply_status_effects
      IMPORTING
        i_minutes TYPE i.

    " Saves current location if Red Card is in inventory
    " Guarda la ubicacion actual si hay una Red Card en el inventario
    METHODS save_state
      RETURNING
        VALUE(r_message) TYPE string.

    " Triggered when health reaches 0 - returns message and resets to last save
    " Se activa cuando la salud llega a 0 - devuelve mensaje y vuelve al ultimo guardado
    METHODS game_over
      RETURNING
        VALUE(r_message) TYPE string.

    " Returns true if character health is at or below zero
    " Devuelve true si la salud del personaje esta en cero o menos
    METHODS is_dead
      RETURNING
        VALUE(r_dead) TYPE abap_bool.

    " Returns a full formatted record of the current character state
    " Devuelve una ficha completa del estado actual del personaje
    METHODS get_status
      RETURNING
        VALUE(r_status) TYPE string.

    " Interface to run the class directly from Eclipse with F9
    " Interface para ejecutar la clase directamente desde Eclipse con F9
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.

    " Private attributes - only accessible from within the class
    " Atributos privados - solo accesibles desde dentro de la clase
    DATA name           TYPE string.
    DATA health         TYPE ty_health.
    DATA max_health     TYPE ty_health.
    DATA location       TYPE string.
    DATA save_location  TYPE string.
    DATA poisoned       TYPE abap_bool.
    DATA blinded        TYPE abap_bool.
    DATA poison_minutes TYPE i.
    DATA lt_inventory   TYPE TABLE OF string.

    " Internal method - keeps health within 0 and max_health bounds
    " Metodo interno - mantiene la salud entre 0 y max_health
    METHODS cap_health.

ENDCLASS.

CLASS zcl_silenthill2_arm IMPLEMENTATION.

  METHOD class_constructor.

    " No encounters with Pyramid Head at game start
    " Sin encuentros con Pyramid Head al inicio del juego
    pyramid_head_encounters = 0.

  ENDMETHOD.

  METHOD create.

    " Validation 1 - name cannot be empty
    " Validacion 1 - el nombre no puede estar vacio
    IF i_name IS INITIAL.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.

    " Validation 2 - starting health must be between 1 and 100
    " Validacion 2 - la salud inicial debe estar entre 1 y 100
    IF i_health <= 0 OR i_health > 100.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.

    " Validation 3 - starting location cannot be empty
    " Validacion 3 - la ubicacion inicial no puede estar vacia
    IF i_location IS INITIAL.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.

    " Create instance and set private attributes directly
    " Class methods can access private attributes of their own class
    " Creamos la instancia y asignamos los atributos privados directamente
    " Los metodos de clase pueden acceder a los atributos privados de su propia clase
    ro_char                 = NEW zcl_silenthill2_arm( ).
    ro_char->name           = i_name.
    ro_char->health         = i_health.
    ro_char->max_health     = 100.
    ro_char->location       = i_location.
    ro_char->save_location  = i_location.
    ro_char->poisoned       = abap_false.
    ro_char->blinded        = abap_false.
    ro_char->poison_minutes = 0.

  ENDMETHOD.

  METHOD cap_health.

    " COND replaces IF/ENDIF for simple conditional assignments
    " COND reemplaza IF/ENDIF para asignaciones condicionales simples
    health = COND #(
      WHEN health > max_health THEN max_health
      WHEN health < 0          THEN 0
      ELSE                          health ).

  ENDMETHOD.

  METHOD heal.

    " SWITCH replaces CASE for value assignment - raises exception for unknown items
    " SWITCH reemplaza CASE para asignacion de valores - lanza excepcion para items desconocidos
    DATA(lv_heal_amount) = SWITCH ty_health( i_item
      WHEN 'Health Drink' THEN 25
      WHEN 'Health Pack'  THEN 50
      ELSE                     0 ).

    " Unknown item type - zero heal amount means invalid item
    " Tipo de item desconocido - cantidad cero significa item invalido
    IF lv_heal_amount = 0.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.

    " Item not in inventory - cannot heal without the item
    " Item no esta en el inventario - no se puede curar sin el item
    IF me->use_item( i_item = i_item ) = abap_false.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.

    " CHECK exits the method immediately if the condition is false
    " CHECK sale del metodo inmediatamente si la condicion es falsa
    CHECK health > 0.

    " Apply healing and cap to current maximum health
    " Aplicamos la curacion y limitamos al maximo de salud actual
    health = health + lv_heal_amount.
    me->cap_health( ).

  ENDMETHOD.

  METHOD add_item.

    " Validation - item name cannot be empty
    " Validacion - el nombre del item no puede estar vacio
    IF i_item IS INITIAL.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.

    " Insert the item at the end of the inventory table
    " Insertamos el item al final de la tabla de inventario
    APPEND i_item TO lt_inventory.

  ENDMETHOD.

  METHOD use_item.

    " line_exists() replaces READ TABLE + sy-subrc check - modern and readable
    " line_exists() reemplaza READ TABLE + sy-subrc - moderno y legible
    IF line_exists( lt_inventory[ table_line = i_item ] ).

      " line_index() returns the position of the item in the table
      " line_index() devuelve la posicion del item en la tabla
      DELETE lt_inventory INDEX line_index( lt_inventory[ table_line = i_item ] ).
      r_used = abap_true.

    ELSE.

      " Item not found - return false without modifying inventory
      " Item no encontrado - devolvemos false sin modificar el inventario
      r_used = abap_false.

    ENDIF.

  ENDMETHOD.

  METHOD pyramid_head_encounter.

    " Increment the static class counter for this encounter
    " Incrementamos el contador estatico de clase para este encuentro
    pyramid_head_encounters = pyramid_head_encounters + 1.

    " Inflict damage and keep health within valid bounds
    " Infligimos danyo y mantenemos la salud dentro de limites validos
    health = health - i_damage.
    me->cap_health( ).

  ENDMETHOD.

  METHOD add_status_effect.

    " SWITCH replaces CASE for flag assignment
    " SWITCH reemplaza CASE para la asignacion de flags
    CASE i_effect.
      WHEN 'POISON'.
        poisoned = abap_true.
      WHEN 'BLIND'.
        blinded  = abap_true.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDCASE.

  ENDMETHOD.

  METHOD remove_status_effect.

    " Deactivate the matching status effect flag and reset its counter
    " Desactivamos el flag del efecto de estado y reiniciamos su contador
    CASE i_effect.
      WHEN 'POISON'.
        poisoned       = abap_false.
        poison_minutes = 0.
      WHEN 'BLIND'.
        blinded = abap_false.
    ENDCASE.

  ENDMETHOD.

  METHOD apply_status_effects.

    " CHECK exits immediately if character is not poisoned - replaces IF block
    " CHECK sale inmediatamente si el personaje no esta envenenado - reemplaza bloque IF
    CHECK poisoned = abap_true.

    " Inline DATA declarations - declared where first used
    " Declaraciones DATA inline - declaradas donde se usan por primera vez
    DATA(lv_blocks_before) = poison_minutes DIV 10.
    DATA(lv_new_minutes)   = poison_minutes + i_minutes.
    DATA(lv_blocks_after)  = lv_new_minutes DIV 10.
    DATA(lv_new_blocks)    = lv_blocks_after - lv_blocks_before.

    " For each new completed 10-minute block reduce max health by 5
    " Por cada nuevo bloque de 10 minutos completado reducimos el maximo en 5
    IF lv_new_blocks > 0.
      max_health = max_health - ( lv_new_blocks * 5 ).
      IF max_health < 0.
        max_health = 0.
      ENDIF.
    ENDIF.

    " Apply 1 HP damage per minute and update total poison minutes
    " Aplicamos 1 HP de danyo por minuto y actualizamos el total de minutos de veneno
    health         = health - i_minutes.
    poison_minutes = lv_new_minutes.

    " Recalculate bounds after all poison damage is applied
    " Recalculamos los limites despues de aplicar todo el danyo del veneno
    me->cap_health( ).

  ENDMETHOD.

  METHOD save_state.

    " line_exists() replaces READ TABLE + sy-subrc for cleaner inventory check
    " line_exists() reemplaza READ TABLE + sy-subrc para una comprobacion mas limpia
    IF line_exists( lt_inventory[ table_line = 'Red Card' ] ).

      " Red Card found - save current location as checkpoint
      " Red Card encontrada - guardamos la ubicacion actual como punto de guardado
      save_location = location.
      r_message     = |Game saved at: { location }.|.

    ELSE.

      " No Red Card in inventory - cannot save
      " No hay Red Card en el inventario - no se puede guardar
      r_message = 'Cannot save: No Red Card found in inventory.'.

    ENDIF.

  ENDMETHOD.

  METHOD game_over.

    " String template replaces && concatenation for multi-value strings
    " El template de string reemplaza && para strings con multiples valores
    r_message = |>>> YOUR GAME IS OVER. THINK TWICE NEXT TIME. <<< \| Returning to last save: { save_location }|.

    " Reset character to last save point with minimum survival health
    " Reiniciamos el personaje al ultimo guardado con salud minima de supervivencia
    location = save_location.
    health   = 10.

  ENDMETHOD.

  METHOD is_dead.

    " xsdbool() converts a boolean expression directly to abap_bool
    " xsdbool() convierte una expresion booleana directamente a abap_bool
    r_dead = xsdbool( health <= 0 ).

  ENDMETHOD.

  METHOD get_status.

    DATA lv_inventory TYPE string.
    DATA lv_effects   TYPE string.

    " LOOP with inline DATA declaration - no need to pre-declare lv_item
    " LOOP con declaracion DATA inline - no hace falta pre-declarar lv_item
    LOOP AT lt_inventory INTO DATA(lv_item).

      " COND builds the inventory string with a comma separator after the first item
      " COND construye el string de inventario con coma separadora a partir del segundo item
      lv_inventory = COND #(
        WHEN lv_inventory IS INITIAL THEN lv_item
        ELSE                              lv_inventory && ', ' && lv_item ).

    ENDLOOP.

    " COND replaces IF IS INITIAL check for default value assignment
    " COND reemplaza el IF IS INITIAL para asignar el valor por defecto
    lv_inventory = COND #(
      WHEN lv_inventory IS INITIAL THEN 'Empty'
      ELSE                              lv_inventory ).

    " COND builds the effects string covering all four possible combinations
    " COND construye el string de efectos cubriendo las cuatro combinaciones posibles
    lv_effects = COND #(
      WHEN poisoned = abap_true AND blinded = abap_true
        THEN |POISONED ({ poison_minutes } min), BLIND|
      WHEN poisoned = abap_true
        THEN |POISONED ({ poison_minutes } min)|
      WHEN blinded = abap_true
        THEN 'BLIND'
      ELSE  'None' ).

    " String templates embed variables directly without && concatenation
    " Los templates de string incrustan variables directamente sin concatenacion &&
    r_status = |[ { name } ] \| HP: { health }/{ max_health } \| Location: { location } \| Effects: { lv_effects } \| Inventory: { lv_inventory }|.
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.

    " lo_char is a pointer to the character object in heap memory
    " lo_char es un puntero al objeto personaje en memoria heap
    DATA lo_char    TYPE REF TO zcl_silenthill2_arm.
    DATA lv_message TYPE string.

    " TRY catches any cx_abap_invalid_value thrown by create or methods
    " TRY captura cualquier cx_abap_invalid_value lanzado por create o los metodos
    TRY.

        " create validates inputs and returns a fully initialized instance
        " create valida los datos y devuelve una instancia completamente inicializada
        lo_char = zcl_silenthill2_arm=>create(
          i_name     = 'James Sunderland'
          i_health   = 80
          i_location = 'Toluca Prison'
        ).

        out->write( '=== Silent Hill 2 - Game Start ===' ).
        out->write( lo_char->get_status( ) ).

        " James picks up items scattered around Toluca Prison
        " James recoge objetos repartidos por Toluca Prison
        lo_char->add_item( 'Health Drink'   ).
        lo_char->add_item( 'Health Pack'    ).
        lo_char->add_item( 'Steel Pipe'     ).
        lo_char->add_item( 'Red Card'       ).
        lo_char->add_item( 'Shotgun Shells' ).

        out->write( '=== After picking up items ===' ).
        out->write( lo_char->get_status( ) ).

        " James finds a save point and uses the Red Card
        " James encuentra un punto de guardado y usa la Red Card
        lv_message = lo_char->save_state( ).
        out->write( lv_message ).

        " First Pyramid Head encounter - 35 damage
        " Primer encuentro con Pyramid Head - 35 de danyo
        lo_char->pyramid_head_encounter( i_damage = 35 ).
        out->write( '=== After first Pyramid Head encounter (-35 HP) ===' ).
        out->write( lo_char->get_status( ) ).

        " James uses a Health Drink to recover 25 HP
        " James usa un Health Drink para recuperar 25 HP
        lo_char->heal( i_item = 'Health Drink' ).
        out->write( '=== After using Health Drink (+25 HP) ===' ).
        out->write( lo_char->get_status( ) ).

        " James gets poisoned by a creature in the prison
        " James se envenena por una criatura en la prision
        lo_char->add_status_effect( i_effect = 'POISON' ).
        out->write( '=== James is now POISONED ===' ).

        " Simulate 15 minutes under poison
        " 15 HP lost, 1 completed block of 10 min = -5 max HP
        " Simulamos 15 minutos bajo veneno
        " 15 HP perdidos, 1 bloque de 10 min completado = -5 max HP
        lo_char->apply_status_effects( i_minutes = 15 ).
        out->write( '=== After 15 minutes of poison (-15 HP, -5 max HP) ===' ).
        out->write( lo_char->get_status( ) ).

        " James also gets blinded by a fog creature
        " James tambien queda cegado por una criatura de la niebla
        lo_char->add_status_effect( i_effect = 'BLIND' ).
        out->write( '=== James is now BLIND ===' ).
        out->write( lo_char->get_status( ) ).

        " James uses a Health Pack to recover 50 HP
        " James usa un Health Pack para recuperar 50 HP
        lo_char->heal( i_item = 'Health Pack' ).
        out->write( '=== After using Health Pack (+50 HP, capped to max) ===' ).
        out->write( lo_char->get_status( ) ).

        " Second Pyramid Head encounter - lethal 90 damage
        " Segundo encuentro con Pyramid Head - 90 de danyo letal
        lo_char->pyramid_head_encounter( i_damage = 90 ).
        out->write( '=== After second Pyramid Head encounter (-90 HP) ===' ).
        out->write( lo_char->get_status( ) ).

        " Check if James died and trigger game over if so
        " Comprobamos si James murio y activamos game over si es el caso
        IF lo_char->is_dead( ) = abap_true.
          out->write( lo_char->game_over( ) ).
          out->write( '=== Respawned at last save ===' ).
          out->write( lo_char->get_status( ) ).
        ENDIF.

        " Try to save again without Red Card
        " Intentamos guardar de nuevo sin Red Card
        lv_message = lo_char->save_state( ).
        out->write( lv_message ).

        " Invalid character - empty name triggers exception in create
        " Personaje invalido - nombre vacio lanza excepcion en create
        lo_char = zcl_silenthill2_arm=>create(
          i_name     = ''
          i_health   = 100
          i_location = 'Nowhere'
        ).

      CATCH cx_abap_invalid_value.

        " Only executes if any validation failed in create or methods
        " Solo se ejecuta si alguna validacion fallo en create o los metodos
        out->write( 'Error: invalid character or item data.' ).

    ENDTRY.

    " Print total Pyramid Head encounters - class data, not instance data
    " Imprimimos el total de encuentros con Pyramid Head - dato de clase, no de instancia
    out->write( |Total Pyramid Head encounters: { zcl_silenthill2_arm=>pyramid_head_encounters }| ).

  ENDMETHOD.

ENDCLASS.

